import Foundation

public actor InMemoryStore: MemoryStoreProtocol {
    private var records: [MemoryRecord] = []
    public var embedder: (any Embedder)?
    public var maxShortTerm: Int
    public var summarizer: (@Sendable ([MemoryRecord]) async throws -> String)?

    public init(
        embedder: (any Embedder)? = nil,
        maxShortTerm: Int = 200,
        summarizer: (@Sendable ([MemoryRecord]) async throws -> String)? = nil
    ) {
        self.embedder = embedder
        self.maxShortTerm = maxShortTerm
        self.summarizer = summarizer
    }

    public func store(_ record: MemoryRecord) async throws {
        var r = record
        if r.embedding == nil, let embedder = embedder {
            r.embedding = try await embedder.embed(r.text)
        }
        records.append(r)
        try await pruneIfNeeded(namespace: r.namespace)
    }

    public func store(batch: [MemoryRecord]) async throws {
        for r in batch { try await store(r) }
    }

    public func retrieve(query: String, namespace: String, limit: Int) async throws -> [MemoryRecord] {
        let candidates = records.filter { $0.namespace == namespace && !$0.isExpired }
        guard let embedder = embedder else {
            return Array(candidates.filter { keywordMatch($0.text, query: query) }.prefix(limit))
        }
        let queryEmbedding = try await embedder.embed(query)
        let scored = candidates.compactMap { r -> (MemoryRecord, Float)? in
            guard let emb = r.embedding else { return nil }
            let score = Self.cosine(queryEmbedding, emb)
            let recency = Float(exp(-Date().timeIntervalSince(r.accessedAt) / 86_400))
            let importance = Float(r.importance)
            return (r, score * 0.7 + recency * 0.2 + importance * 0.1)
        }
        var top = scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
        for i in top.indices { top[i].accessedAt = Date() }
        for t in top {
            if let idx = records.firstIndex(where: { $0.id == t.id }) {
                records[idx] = t
            }
        }
        return Array(top)
    }

    public func retrieveByEntity(_ entity: String, namespace: String, limit: Int) async throws -> [MemoryRecord] {
        let lowered = entity.lowercased()
        return records.filter {
            $0.namespace == namespace &&
            !$0.isExpired &&
            $0.entities.contains(where: { $0.lowercased() == lowered })
        }.sorted { $0.createdAt > $1.createdAt }.prefix(limit).map { $0 }
    }

    public func forget(id: UUID) async throws {
        records.removeAll { $0.id == id }
    }

    public func forget(matching predicate: @Sendable (MemoryRecord) -> Bool) async throws {
        records.removeAll(where: predicate)
    }

    public func all(namespace: String) async throws -> [MemoryRecord] {
        records.filter { $0.namespace == namespace && !$0.isExpired }
    }

    public func context(for query: String, namespace: String, maxCharacters: Int) async throws -> String {
        let relevant = try await retrieve(query: query, namespace: namespace, limit: 16)
        var out = ""
        for r in relevant {
            if out.count + r.text.count + 2 > maxCharacters { break }
            if !out.isEmpty { out += "\n" }
            out += "- \(r.text)"
        }
        return out
    }

    public func compact(namespace: String) async throws {
        let old = records.filter { $0.namespace == namespace && $0.kind == .shortTerm }
        guard old.count > maxShortTerm / 2 else { return }
        guard let summarizer else { return }
        let chunk = Array(old.prefix(old.count - maxShortTerm / 2))
        let summary = try await summarizer(chunk)
        let ids = Set(chunk.map(\.id))
        records.removeAll { ids.contains($0.id) }
        records.append(MemoryRecord(
            kind: .summary,
            namespace: namespace,
            text: summary,
            importance: 0.7
        ))
    }

    public func exportAll() async throws -> Data {
        try JSONEncoder().encode(records)
    }

    public func importAll(_ data: Data) async throws {
        let imported = try JSONDecoder().decode([MemoryRecord].self, from: data)
        records.append(contentsOf: imported)
    }

    private func pruneIfNeeded(namespace: String) async throws {
        records.removeAll { $0.isExpired }
        let shortTerm = records.filter { $0.namespace == namespace && $0.kind == .shortTerm }
        if shortTerm.count > maxShortTerm {
            try await compact(namespace: namespace)
            let overflow = shortTerm.count - maxShortTerm
            if overflow > 0 {
                let oldest = shortTerm.sorted { $0.createdAt < $1.createdAt }.prefix(overflow).map(\.id)
                let oldestSet = Set(oldest)
                records.removeAll { oldestSet.contains($0.id) }
            }
        }
    }

    private func keywordMatch(_ text: String, query: String) -> Bool {
        let tokens = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let lower = text.lowercased()
        for t in tokens where lower.contains(t) { return true }
        return false
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom > 0 ? dot / denom : 0
    }
}
