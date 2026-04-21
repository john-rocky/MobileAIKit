import Foundation
import AIKit

public struct WebSearchResult: Sendable, Hashable, Codable {
    public let title: String
    public let url: String
    public let snippet: String

    public init(title: String, url: String, snippet: String) {
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

public protocol WebSearchProvider: Sendable {
    var name: String { get }
    func search(query: String, limit: Int) async throws -> [WebSearchResult]
}

public struct DuckDuckGoSearchProvider: WebSearchProvider {
    public let name = "duckduckgo"
    public let session: URLSession
    public let userAgent: String

    public init(
        session: URLSession = .shared,
        userAgent: String = "LocalAIKit/1.0 (iOS)"
    ) {
        self.session = session
        self.userAgent = userAgent
    }

    public func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        var components = URLComponents(string: "https://duckduckgo.com/html/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIError.networkUnavailable
        }
        let html = String(decoding: data, as: UTF8.self)
        return DuckDuckGoSearchProvider.parse(html: html, limit: limit)
    }

    static func parse(html: String, limit: Int) -> [WebSearchResult] {
        var results: [WebSearchResult] = []
        let pattern = #"<a[^>]*class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>[\s\S]*?<a[^>]*class=\"result__snippet\"[^>]*>([\s\S]*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        for m in matches.prefix(limit) where m.numberOfRanges >= 4 {
            let rawURL = ns.substring(with: m.range(at: 1))
            let title = stripTags(ns.substring(with: m.range(at: 2)))
            let snippet = stripTags(ns.substring(with: m.range(at: 3)))
            let decodedURL = decodeDDGRedirect(rawURL)
            results.append(WebSearchResult(title: title, url: decodedURL, snippet: snippet))
        }
        return results
    }

    private static func decodeDDGRedirect(_ raw: String) -> String {
        if raw.hasPrefix("/l/?") || raw.contains("duckduckgo.com/l/") {
            if let comp = URLComponents(string: "https://duckduckgo.com\(raw.hasPrefix("/") ? raw : "/\(raw)")"),
               let uddg = comp.queryItems?.first(where: { $0.name == "uddg" })?.value,
               let decoded = uddg.removingPercentEncoding {
                return decoded
            }
        }
        return raw
    }

    private static func stripTags(_ s: String) -> String {
        let without = s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        return without
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BraveSearchProvider: WebSearchProvider {
    public let name = "brave"
    public let session: URLSession
    public let apiKey: String

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        var components = URLComponents(string: "https://api.search.brave.com/res/v1/web/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(limit))
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIError.networkUnavailable
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.web?.results?.prefix(limit).map {
            WebSearchResult(title: $0.title, url: $0.url, snippet: $0.description ?? "")
        } ?? []
    }

    struct Response: Decodable { let web: Web? }
    struct Web: Decodable { let results: [Item]? }
    struct Item: Decodable { let title: String; let url: String; let description: String? }
}

public struct BingSearchProvider: WebSearchProvider {
    public let name = "bing"
    public let session: URLSession
    public let apiKey: String
    public let endpoint: URL

    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.bing.microsoft.com/v7.0/search")!,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.session = session
    }

    public func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(limit))
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIError.networkUnavailable
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.webPages?.value?.prefix(limit).map {
            WebSearchResult(title: $0.name, url: $0.url, snippet: $0.snippet ?? "")
        } ?? []
    }

    struct Response: Decodable { let webPages: Pages? }
    struct Pages: Decodable { let value: [Item]? }
    struct Item: Decodable { let name: String; let url: String; let snippet: String? }
}

public enum WebSearch {
    public static func tool(provider: any WebSearchProvider) -> any Tool {
        let spec = ToolSpec(
            name: "web_search",
            description: "Search the web for current information via \(provider.name).",
            parameters: .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "limit": .integer(minimum: 1, maximum: 20)
                ],
                required: ["query"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let query: String; let limit: Int? }
        return TypedTool(spec: spec) { (args: Args) async throws -> [WebSearchResult] in
            try await provider.search(query: args.query, limit: args.limit ?? 5)
        }
    }
}
