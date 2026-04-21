import Foundation
import AIKit

public extension AIKit {
    /// Free on-device web search via DuckDuckGo HTML.
    static func searchWeb(
        _ query: String,
        limit: Int = 5,
        provider: any WebSearchProvider = DuckDuckGoSearchProvider()
    ) async throws -> [WebSearchResult] {
        try await provider.search(query: query, limit: limit)
    }

    /// Fetch and extract the readable text of a URL.
    static func readWebPage(_ url: URL) async throws -> WebPage {
        try await WebPageReader.fetch(url: url)
    }

    /// One-line "LLM + web": searches the web, reads top pages, answers with citations.
    static func browseAndAsk(
        _ question: String,
        backend: any AIBackend,
        provider: any WebSearchProvider = DuckDuckGoSearchProvider(),
        maxPages: Int = 3
    ) async throws -> String {
        let results = try await provider.search(query: question, limit: maxPages)
        var context = ""
        for r in results {
            if let url = URL(string: r.url), let page = try? await WebPageReader.fetch(url: url) {
                let excerpt = String(page.text.prefix(1500))
                context += "[\(r.url)] \(excerpt)\n---\n"
            }
        }
        return try await AIKit.chat(
            "Question: \(question)\n\nSources:\n\(context)\n\nAnswer concisely, citing URLs in brackets.",
            backend: backend,
            systemPrompt: "Answer using only the provided sources. Always cite URLs."
        )
    }

    /// Shortest "agentic web" call — alias of ``browseAndAsk(_:backend:provider:maxPages:)``.
    static func askWeb(_ question: String, backend: any AIBackend) async throws -> String {
        try await browseAndAsk(question, backend: backend)
    }

    /// LLM with `web_search` + `read_web_page` tools registered. Lets the model decide when to search.
    static func askWithWebTools(
        _ question: String,
        backend: any AIBackend,
        provider: any WebSearchProvider = DuckDuckGoSearchProvider(),
        systemPrompt: String? = "Use web_search and read_web_page when you need fresh information. Cite URLs."
    ) async throws -> String {
        let registry = ToolRegistry(cache: ToolResultCache(), retry: ToolRetry())
        await registry.register(WebSearch.tool(provider: provider))
        await registry.register(WebPageReader.readerTool())
        return try await AIKit.askWithTools(question, tools: registry, backend: backend, systemPrompt: systemPrompt)
    }
}
