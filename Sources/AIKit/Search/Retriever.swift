import Foundation

public struct Retriever: Sendable {
    public let search: @Sendable (String) async throws -> [RetrievedDocument]
    public var reranker: (@Sendable (String, [RetrievedDocument]) async throws -> [RetrievedDocument])?
    public var limit: Int

    public init(
        limit: Int = 4,
        reranker: (@Sendable (String, [RetrievedDocument]) async throws -> [RetrievedDocument])? = nil,
        search: @Sendable @escaping (String) async throws -> [RetrievedDocument]
    ) {
        self.limit = limit
        self.reranker = reranker
        self.search = search
    }

    public func retrieve(query: String) async throws -> [RetrievedDocument] {
        let initial = try await search(query)
        let reranked = try await (reranker?(query, initial) ?? initial)
        return Array(reranked.prefix(limit))
    }

    public static func vectorIndex(_ index: VectorIndex, limit: Int = 4) -> Retriever {
        Retriever(limit: limit) { query in
            try await index.search(query: query, limit: limit * 2)
        }
    }
}
