import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public actor DatabaseMemoryStore: MemoryStoreProtocol {
    public let fileURL: URL
    public var embedder: (any Embedder)?
    public var maxShortTerm: Int
    public var summarizer: (@Sendable ([MemoryRecord]) async throws -> String)?

    private var db: OpaquePointer?

    public init(
        fileURL: URL? = nil,
        embedder: (any Embedder)? = nil,
        maxShortTerm: Int = 500,
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
            self.fileURL = dir.appendingPathComponent("memory.sqlite3")
        }
        self.embedder = embedder
        self.maxShortTerm = maxShortTerm
        self.summarizer = summarizer
        try open()
        try migrate()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func open() throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let code = fileURL.path.withCString { cstr in
            sqlite3_open_v2(cstr, &handle, flags, nil)
        }
        if code != SQLITE_OK {
            throw AIError.resourceUnavailable("sqlite open failed: \(code)")
        }
        self.db = handle
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
    }

    private func migrate() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS memory_records (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            namespace TEXT NOT NULL,
            text TEXT NOT NULL,
            entities TEXT NOT NULL,
            importance REAL NOT NULL,
            embedding BLOB,
            expires_at REAL,
            created_at REAL NOT NULL,
            accessed_at REAL NOT NULL,
            source TEXT,
            metadata TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_namespace ON memory_records(namespace);
        CREATE INDEX IF NOT EXISTS idx_kind ON memory_records(kind);
        CREATE INDEX IF NOT EXISTS idx_created ON memory_records(created_at);
        CREATE VIRTUAL TABLE IF NOT EXISTS memory_fts USING fts5(
            id UNINDEXED, text, entities, content='memory_records', content_rowid='rowid'
        );
        CREATE TRIGGER IF NOT EXISTS memory_records_ai AFTER INSERT ON memory_records BEGIN
            INSERT INTO memory_fts(rowid, id, text, entities) VALUES (new.rowid, new.id, new.text, new.entities);
        END;
        CREATE TRIGGER IF NOT EXISTS memory_records_ad AFTER DELETE ON memory_records BEGIN
            INSERT INTO memory_fts(memory_fts, rowid, id, text, entities) VALUES ('delete', old.rowid, old.id, old.text, old.entities);
        END;
        CREATE TRIGGER IF NOT EXISTS memory_records_au AFTER UPDATE ON memory_records BEGIN
            INSERT INTO memory_fts(memory_fts, rowid, id, text, entities) VALUES ('delete', old.rowid, old.id, old.text, old.entities);
            INSERT INTO memory_fts(rowid, id, text, entities) VALUES (new.rowid, new.id, new.text, new.entities);
        END;
        """
        var errmsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errmsg) != SQLITE_OK {
            let msg = errmsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errmsg)
            throw AIError.resourceUnavailable("migration failed: \(msg)")
        }
    }

    public func store(_ record: MemoryRecord) async throws {
        var r = record
        if r.embedding == nil, let embedder {
            r.embedding = try await embedder.embed(r.text)
        }
        let sql = """
        INSERT OR REPLACE INTO memory_records
        (id, kind, namespace, text, entities, importance, embedding, expires_at, created_at, accessed_at, source, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw AIError.resourceUnavailable("prepare failed")
        }
        sqlite3_bind_text(stmt, 1, r.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, r.kind.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, r.namespace, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, r.text, -1, SQLITE_TRANSIENT)
        let entitiesJSON = (try? String(data: JSONEncoder().encode(r.entities), encoding: .utf8)) ?? "[]"
        sqlite3_bind_text(stmt, 5, entitiesJSON, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 6, r.importance)
        if let emb = r.embedding {
            let data = Self.embeddingData(emb)
            _ = data.withUnsafeBytes { raw in
                sqlite3_bind_blob(stmt, 7, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        if let expires = r.expiresAt {
            sqlite3_bind_double(stmt, 8, expires.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        sqlite3_bind_double(stmt, 9, r.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 10, r.accessedAt.timeIntervalSince1970)
        if let source = r.source {
            sqlite3_bind_text(stmt, 11, source, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 11)
        }
        let metaJSON = (try? String(data: JSONEncoder().encode(r.metadata), encoding: .utf8)) ?? "{}"
        sqlite3_bind_text(stmt, 12, metaJSON, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw AIError.resourceUnavailable("insert failed")
        }
        try pruneIfNeeded(namespace: r.namespace)
    }

    public func store(batch: [MemoryRecord]) async throws {
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        do {
            for r in batch { try await store(r) }
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        } catch {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw error
        }
    }

    public func retrieve(query: String, namespace: String, limit: Int) async throws -> [MemoryRecord] {
        let now = Date().timeIntervalSince1970
        var candidates = try fetchAll(whereClause: "namespace = ? AND (expires_at IS NULL OR expires_at > ?)", binds: [.text(namespace), .double(now)])
        if candidates.isEmpty { return [] }

        if let embedder = embedder {
            let q = try await embedder.embed(query)
            let scored = candidates.compactMap { r -> (MemoryRecord, Float)? in
                guard let emb = r.embedding else { return nil }
                let s = Self.cosine(q, emb)
                let recency = Float(exp(-Date().timeIntervalSince(r.accessedAt) / 86_400))
                let importance = Float(r.importance)
                return (r, s * 0.7 + recency * 0.2 + importance * 0.1)
            }
            let top = scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
            try touchAccess(top.map(\.id))
            return top
        } else {
            let ftsIds = try ftsSearch(query: query, namespace: namespace, limit: limit)
            let set = Set(ftsIds)
            candidates = candidates.filter { set.contains($0.id) }
            try touchAccess(candidates.map(\.id))
            return Array(candidates.prefix(limit))
        }
    }

    public func retrieveByEntity(_ entity: String, namespace: String, limit: Int) async throws -> [MemoryRecord] {
        let like = "%\"\(entity.lowercased())\"%"
        let now = Date().timeIntervalSince1970
        let rows = try fetchAll(
            whereClause: "namespace = ? AND LOWER(entities) LIKE ? AND (expires_at IS NULL OR expires_at > ?) ORDER BY created_at DESC LIMIT \(max(1, limit))",
            binds: [.text(namespace), .text(like), .double(now)]
        )
        return rows
    }

    public func forget(id: UUID) async throws {
        let sql = "DELETE FROM memory_records WHERE id = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    public func forget(matching predicate: @Sendable (MemoryRecord) -> Bool) async throws {
        let all = try fetchAll(whereClause: "1=1", binds: [])
        for r in all where predicate(r) { try await forget(id: r.id) }
    }

    public func all(namespace: String) async throws -> [MemoryRecord] {
        let now = Date().timeIntervalSince1970
        return try fetchAll(
            whereClause: "namespace = ? AND (expires_at IS NULL OR expires_at > ?) ORDER BY created_at DESC",
            binds: [.text(namespace), .double(now)]
        )
    }

    public func context(for query: String, namespace: String, maxCharacters: Int) async throws -> String {
        let items = try await retrieve(query: query, namespace: namespace, limit: 16)
        var out = ""
        for r in items {
            if out.count + r.text.count + 2 > maxCharacters { break }
            if !out.isEmpty { out += "\n" }
            out += "- \(r.text)"
        }
        return out
    }

    public func compact(namespace: String) async throws {
        let now = Date().timeIntervalSince1970
        let shortTerm = try fetchAll(
            whereClause: "namespace = ? AND kind = 'shortTerm' AND (expires_at IS NULL OR expires_at > ?) ORDER BY created_at ASC",
            binds: [.text(namespace), .double(now)]
        )
        guard shortTerm.count > maxShortTerm / 2 else { return }
        guard let summarizer else { return }
        let chunk = Array(shortTerm.prefix(shortTerm.count - maxShortTerm / 2))
        let summary = try await summarizer(chunk)
        for r in chunk { try await forget(id: r.id) }
        try await store(MemoryRecord(
            kind: .summary,
            namespace: namespace,
            text: summary,
            importance: 0.7
        ))
    }

    public func exportAll() async throws -> Data {
        let rows = try fetchAll(whereClause: "1=1", binds: [])
        return try JSONEncoder().encode(rows)
    }

    public func importAll(_ data: Data) async throws {
        let rows = try JSONDecoder().decode([MemoryRecord].self, from: data)
        try await store(batch: rows)
    }

    private func pruneIfNeeded(namespace: String) throws {
        let sql = "DELETE FROM memory_records WHERE namespace = ? AND kind = 'shortTerm' AND id IN (SELECT id FROM memory_records WHERE namespace = ? AND kind = 'shortTerm' ORDER BY created_at ASC LIMIT max(0, (SELECT COUNT(*) FROM memory_records WHERE namespace = ? AND kind = 'shortTerm') - ?));"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, namespace, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, namespace, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, namespace, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, Int32(maxShortTerm))
        sqlite3_step(stmt)
    }

    private enum Bind { case text(String); case int(Int); case double(Double); case null; case blob(Data) }

    private func bind(_ binds: [Bind], to stmt: OpaquePointer?) {
        for (i, b) in binds.enumerated() {
            let idx = Int32(i + 1)
            switch b {
            case .text(let t): sqlite3_bind_text(stmt, idx, t, -1, SQLITE_TRANSIENT)
            case .int(let n): sqlite3_bind_int64(stmt, idx, Int64(n))
            case .double(let d): sqlite3_bind_double(stmt, idx, d)
            case .null: sqlite3_bind_null(stmt, idx)
            case .blob(let data):
                _ = data.withUnsafeBytes { raw in
                    sqlite3_bind_blob(stmt, idx, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
                }
            }
        }
    }

    private func fetchAll(whereClause: String, binds: [Bind]) throws -> [MemoryRecord] {
        let sql = "SELECT id, kind, namespace, text, entities, importance, embedding, expires_at, created_at, accessed_at, source, metadata FROM memory_records WHERE \(whereClause);"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw AIError.resourceUnavailable("prepare failed")
        }
        bind(binds, to: stmt)
        var result: [MemoryRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(try decodeRow(stmt: stmt))
        }
        return result
    }

    private func decodeRow(stmt: OpaquePointer?) throws -> MemoryRecord {
        guard let stmt else { throw AIError.resourceUnavailable("null stmt") }
        let idStr = String(cString: sqlite3_column_text(stmt, 0))
        let kindStr = String(cString: sqlite3_column_text(stmt, 1))
        let namespace = String(cString: sqlite3_column_text(stmt, 2))
        let text = String(cString: sqlite3_column_text(stmt, 3))
        let entitiesStr = String(cString: sqlite3_column_text(stmt, 4))
        let importance = sqlite3_column_double(stmt, 5)
        var embedding: [Float]?
        if sqlite3_column_type(stmt, 6) == SQLITE_BLOB, let bytes = sqlite3_column_blob(stmt, 6) {
            let count = Int(sqlite3_column_bytes(stmt, 6)) / MemoryLayout<Float>.size
            embedding = Array(UnsafeBufferPointer<Float>(start: bytes.assumingMemoryBound(to: Float.self), count: count))
        }
        var expiresAt: Date?
        if sqlite3_column_type(stmt, 7) != SQLITE_NULL {
            expiresAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
        }
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
        let accessedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
        var source: String?
        if sqlite3_column_type(stmt, 10) != SQLITE_NULL {
            source = String(cString: sqlite3_column_text(stmt, 10))
        }
        let metaStr = String(cString: sqlite3_column_text(stmt, 11))
        let entities = (try? JSONDecoder().decode([String].self, from: Data(entitiesStr.utf8))) ?? []
        let metadata = (try? JSONDecoder().decode([String: String].self, from: Data(metaStr.utf8))) ?? [:]
        let id = UUID(uuidString: idStr) ?? UUID()
        let kind = MemoryKind(rawValue: kindStr) ?? .shortTerm
        return MemoryRecord(
            id: id,
            kind: kind,
            namespace: namespace,
            text: text,
            entities: entities,
            importance: importance,
            embedding: embedding,
            expiresAt: expiresAt,
            createdAt: createdAt,
            accessedAt: accessedAt,
            source: source,
            metadata: metadata
        )
    }

    private func ftsSearch(query: String, namespace: String, limit: Int) throws -> [UUID] {
        let escaped = query.replacingOccurrences(of: "\"", with: "\"\"")
        let sql = """
        SELECT r.id FROM memory_records r
        JOIN memory_fts f ON f.rowid = r.rowid
        WHERE f.text MATCH ? AND r.namespace = ?
        LIMIT \(max(1, limit));
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, "\"\(escaped)\"", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, namespace, -1, SQLITE_TRANSIENT)
        var ids: [UUID] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            if let id = UUID(uuidString: idStr) { ids.append(id) }
        }
        return ids
    }

    private func touchAccess(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let now = Date().timeIntervalSince1970
        let sql = "UPDATE memory_records SET accessed_at = ? WHERE id = ?;"
        for id in ids {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_double(stmt, 1, now)
            sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    private static func embeddingData(_ v: [Float]) -> Data {
        v.withUnsafeBufferPointer { buf in Data(buffer: buf) }
    }

    private static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let d = na.squareRoot() * nb.squareRoot()
        return d > 0 ? dot / d : 0
    }
}
