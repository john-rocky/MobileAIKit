import Foundation
import AIKit

enum SkillsExample {
    static func summarize(backend: any AIBackend) async throws -> String {
        let skills = Skills(backend: backend)
        let long = """
        MobileAIKit wraps CoreML-LLM, MLX, llama.cpp and Apple Foundation Models
        behind a single Swift API. Developers can swap runtimes, compose tools,
        build RAG pipelines, and ship SwiftUI chat interfaces in a few lines.
        """
        return try await skills.summarize(long, style: .oneLine)
    }

    static func tag(backend: any AIBackend) async throws -> [String] {
        let skills = Skills(backend: backend)
        return try await skills.tag("A new vegan ramen shop opened in Shibuya last Friday.")
    }

    static func compare(backend: any AIBackend) async throws -> Skills.ComparisonResult {
        let skills = Skills(backend: backend)
        return try await skills.compare(
            "Local LLMs run offline with strong privacy but slower speeds.",
            "Cloud LLMs offer top quality but require network and data sharing.",
            criterion: "on-device AI trade-offs"
        )
    }
}
