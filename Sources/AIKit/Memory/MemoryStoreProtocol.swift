import Foundation

public protocol MemoryStoreProtocol: Sendable, AnyObject {
    func store(_ record: MemoryRecord) async throws
    func store(batch: [MemoryRecord]) async throws
    func record(user: String, assistant: String, namespace: String) async throws
    func retrieve(query: String, namespace: String, limit: Int) async throws -> [MemoryRecord]
    func retrieveByEntity(_ entity: String, namespace: String, limit: Int) async throws -> [MemoryRecord]
    func forget(id: UUID) async throws
    func forget(matching predicate: @Sendable (MemoryRecord) -> Bool) async throws
    func all(namespace: String) async throws -> [MemoryRecord]
    func context(for query: String, namespace: String, maxCharacters: Int) async throws -> String
    func compact(namespace: String) async throws
    func exportAll() async throws -> Data
    func importAll(_ data: Data) async throws
}

public extension MemoryStoreProtocol {
    func record(user: String, assistant: String, namespace: String = "default") async throws {
        try await store(MemoryRecord(
            kind: .shortTerm,
            namespace: namespace,
            text: "User: \(user)\nAssistant: \(assistant)"
        ))
    }

    func retrieve(query: String, limit: Int = 8) async throws -> [MemoryRecord] {
        try await retrieve(query: query, namespace: "default", limit: limit)
    }

    func context(for query: String, maxCharacters: Int = 2000) async throws -> String {
        try await context(for: query, namespace: "default", maxCharacters: maxCharacters)
    }

    func retrieveByEntity(_ entity: String, limit: Int = 8) async throws -> [MemoryRecord] {
        try await retrieveByEntity(entity, namespace: "default", limit: limit)
    }
}
