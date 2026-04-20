import Foundation
import AIKit

enum DocumentQAExample {
    static func buildIndex(documents: [(source: String, text: String)]) async throws -> VectorIndex {
        let embedder = HashingEmbedder(dimension: 512)
        let index = VectorIndex(embedder: embedder)
        let chunker = Chunker()
        for doc in documents {
            try await index.add(chunker.chunk(doc.text, source: doc.source))
        }
        return index
    }

    static func askWithCitations(
        query: String,
        index: VectorIndex,
        backend: any AIBackend
    ) async throws -> (answer: String, citations: [RetrievedDocument]) {
        let docs = try await index.search(query: query, limit: 4)
        let context = docs.map { "[\($0.source)] \($0.text)" }.joined(separator: "\n---\n")
        let answer = try await AIKit.chat(
            "Question: \(query)\n\nContext:\n\(context)",
            backend: backend,
            systemPrompt: "Answer using only the context. If unknown, say 'I don't know'."
        )
        return (answer, docs)
    }
}
