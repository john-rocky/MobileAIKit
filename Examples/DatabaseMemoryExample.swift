import Foundation
import AIKit

enum DatabaseMemoryExample {
    @MainActor
    static func run(backend: any AIBackend) async throws {
        let embedder = HashingEmbedder(dimension: 256)
        let memory = try DatabaseMemoryStore(embedder: embedder, maxShortTerm: 1_000)
        let session = ChatSession(
            backend: backend,
            systemPrompt: "You retain facts the user shares.",
            memory: memory
        )
        _ = try await session.send("Remember: I run every Tuesday morning.")
        _ = try await session.send("Remember: my son's birthday is October 3.")
        _ = try await session.send("What should I plan for next week?")
    }
}
