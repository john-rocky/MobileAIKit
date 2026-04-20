import Foundation

public actor PersistentMemoryStore: MemoryStoreProtocol {
    private let fileURL: URL
    private var backing: InMemoryStore
    private var saveTask: Task<Void, Never>?

    public init(
        fileURL: URL? = nil,
        embedder: (any Embedder)? = nil,
        maxShortTerm: Int = 200,
        summarizer: (@Sendable ([MemoryRecord]) async throws -> String)? = nil
    ) throws {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = base.appendingPathComponent("AIKit", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("memory.json")
        }
        self.backing = InMemoryStore(embedder: embedder, maxShortTerm: maxShortTerm, summarizer: summarizer)
        try loadSync()
    }

    private func loadSync() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        let records = try JSONDecoder().decode([MemoryRecord].self, from: data)
        Task { [backing] in
            for r in records { try? await backing.store(r) }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [backing, fileURL] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            if let data = try? await backing.exportAll() {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    public func store(_ record: MemoryRecord) async throws {
        try await backing.store(record)
        scheduleSave()
    }

    public func store(batch: [MemoryRecord]) async throws {
        try await backing.store(batch: batch)
        scheduleSave()
    }

    public func retrieve(query: String, namespace: String, limit: Int) async throws -> [MemoryRecord] {
        try await backing.retrieve(query: query, namespace: namespace, limit: limit)
    }

    public func retrieveByEntity(_ entity: String, namespace: String, limit: Int) async throws -> [MemoryRecord] {
        try await backing.retrieveByEntity(entity, namespace: namespace, limit: limit)
    }

    public func forget(id: UUID) async throws {
        try await backing.forget(id: id)
        scheduleSave()
    }

    public func forget(matching predicate: @Sendable (MemoryRecord) -> Bool) async throws {
        try await backing.forget(matching: predicate)
        scheduleSave()
    }

    public func all(namespace: String) async throws -> [MemoryRecord] {
        try await backing.all(namespace: namespace)
    }

    public func context(for query: String, namespace: String, maxCharacters: Int) async throws -> String {
        try await backing.context(for: query, namespace: namespace, maxCharacters: maxCharacters)
    }

    public func compact(namespace: String) async throws {
        try await backing.compact(namespace: namespace)
        scheduleSave()
    }

    public func exportAll() async throws -> Data {
        try await backing.exportAll()
    }

    public func importAll(_ data: Data) async throws {
        try await backing.importAll(data)
        scheduleSave()
    }
}
