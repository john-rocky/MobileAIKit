import Foundation

public struct Document: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public var source: String
    public var text: String
    public var metadata: [String: String]

    public init(id: UUID = UUID(), source: String, text: String, metadata: [String: String] = [:]) {
        self.id = id
        self.source = source
        self.text = text
        self.metadata = metadata
    }
}

public struct RAGAnswer: Sendable, Hashable {
    public let answer: String
    public let citations: [RetrievedDocument]
    public let query: String

    public init(answer: String, citations: [RetrievedDocument], query: String) {
        self.answer = answer
        self.citations = citations
        self.query = query
    }
}

public actor RAGPipeline {
    public let embedder: any Embedder
    public let index: VectorIndex
    public let chunker: Chunker
    public var reranker: (@Sendable (String, [RetrievedDocument]) async throws -> [RetrievedDocument])?
    public var retrievalLimit: Int
    public var contextBudgetChars: Int
    public var sourceTrustScore: (@Sendable (String) -> Float)?

    public init(
        embedder: any Embedder,
        chunker: Chunker = Chunker(),
        retrievalLimit: Int = 6,
        contextBudgetChars: Int = 6_000,
        reranker: (@Sendable (String, [RetrievedDocument]) async throws -> [RetrievedDocument])? = nil,
        sourceTrustScore: (@Sendable (String) -> Float)? = nil
    ) {
        self.embedder = embedder
        self.chunker = chunker
        self.index = VectorIndex(embedder: embedder)
        self.retrievalLimit = retrievalLimit
        self.contextBudgetChars = contextBudgetChars
        self.reranker = reranker
        self.sourceTrustScore = sourceTrustScore
    }

    public func ingest(_ document: Document) async throws {
        let chunks = chunker.chunk(document.text, source: document.source, metadata: document.metadata)
        try await index.add(chunks)
    }

    public func ingest(_ documents: [Document]) async throws {
        for doc in documents { try await ingest(doc) }
    }

    public func ingest(text: String, source: String, metadata: [String: String] = [:]) async throws {
        try await ingest(Document(source: source, text: text, metadata: metadata))
    }

    public func retrieve(_ query: String) async throws -> [RetrievedDocument] {
        var docs = try await index.search(query: query, limit: retrievalLimit * 2)
        if let reranker { docs = try await reranker(query, docs) }
        if let trust = sourceTrustScore {
            docs = docs.map { RetrievedDocument(chunk: $0.chunk, score: $0.score * trust($0.source), keywordScore: $0.keywordScore, vectorScore: $0.vectorScore) }
            docs.sort { $0.score > $1.score }
        }
        return Array(docs.prefix(retrievalLimit))
    }

    public func ask(
        _ query: String,
        backend: any AIBackend,
        instruction: String = "Answer concisely and cite sources as [source]. Say 'I don't know' if unsupported by context."
    ) async throws -> RAGAnswer {
        let docs = try await retrieve(query)
        let context = Self.buildContext(docs: docs, budget: contextBudgetChars)
        let systemPrompt = instruction
        let userPrompt = """
        Question: \(query)

        Context:
        \(context)
        """
        let messages: [Message] = [
            .system(systemPrompt),
            .user(userPrompt)
        ]
        let result = try await backend.generate(messages: messages, tools: [], config: .deterministic)
        return RAGAnswer(answer: result.message.content, citations: docs, query: query)
    }

    public func askStream(
        _ query: String,
        backend: any AIBackend,
        instruction: String = "Answer concisely and cite sources as [source]."
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let docs = try await self.retrieve(query)
                    let context = Self.buildContext(docs: docs, budget: await self.contextBudgetChars)
                    let userPrompt = "Question: \(query)\n\nContext:\n\(context)"
                    let messages: [Message] = [.system(instruction), .user(userPrompt)]
                    for try await chunk in backend.stream(messages: messages, tools: [], config: .deterministic) {
                        if !chunk.delta.isEmpty { continuation.yield(chunk.delta) }
                        if chunk.finished { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func retriever() -> Retriever {
        Retriever(limit: retrievalLimit) { [weak self] query in
            guard let self else { return [] }
            return try await self.retrieve(query)
        }
    }

    static func buildContext(docs: [RetrievedDocument], budget: Int) -> String {
        var out = ""
        for d in docs {
            let entry = "[\(d.source)] \(d.text)"
            if out.count + entry.count + 4 > budget { break }
            if !out.isEmpty { out += "\n---\n" }
            out += entry
        }
        return out
    }
}
