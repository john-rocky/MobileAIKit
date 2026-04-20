import Foundation
import AIKit

enum RAGExample {
    static func run(backend: any AIBackend) async throws -> RAGAnswer {
        let embedder = HashingEmbedder(dimension: 384)
        let rag = RAGPipeline(embedder: embedder)

        try await rag.ingest(text: """
            The Swift language was introduced by Apple at WWDC 2014.
            Swift 6 ships with strict concurrency checking.
            """,
            source: "swift-history.txt"
        )
        try await rag.ingest(text: """
            CoreML provides on-device inference on Apple platforms.
            The Neural Engine accelerates CoreML models on recent iPhones.
            """,
            source: "coreml-notes.txt"
        )

        return try await rag.ask(
            "When was Swift introduced and which engine accelerates CoreML?",
            backend: backend
        )
    }
}
