import Foundation
import AIKit

public extension AIKit {
    static func searchWeb(
        _ query: String,
        limit: Int = 5,
        provider: any WebSearchProvider = DuckDuckGoSearchProvider()
    ) async throws -> [WebSearchResult] {
        try await provider.search(query: query, limit: limit)
    }

    static func readWebPage(_ url: URL) async throws -> WebPage {
        try await WebPageReader.fetch(url: url)
    }

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
}
