import Foundation
import AIKit

enum MemoryExample {
    @MainActor
    static func run(backend: any AIBackend) async throws {
        let embedder = HashingEmbedder(dimension: 384)
        let memory = InMemoryStore(embedder: embedder)
        let session = ChatSession(
            backend: backend,
            systemPrompt: "You remember what the user told you.",
            memory: memory
        )

        _ = try await session.send("My favourite drink is matcha latte, and my birthday is May 14.")
        try await Task.sleep(nanoseconds: 100_000_000)
        _ = try await session.send("What gifts would you recommend for me next week?")
    }
}
