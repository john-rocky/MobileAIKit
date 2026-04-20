import Foundation
import AIKit
import AIKitIntegration

enum WebSearchAgent {
    @MainActor
    static func run(backend: any AIBackend) async throws -> String {
        let registry = ToolRegistry(cache: ToolResultCache(), retry: ToolRetry())
        await registry.register(WebSearch.tool(provider: DuckDuckGoSearchProvider()))
        await registry.register(WebPageReader.readerTool())

        return try await AIKit.askWithTools(
            "What is MobileAIKit and who built it? Cite sources.",
            tools: registry,
            backend: backend,
            systemPrompt: "Use web_search then read_web_page to gather facts. Cite URLs in the answer."
        )
    }
}
