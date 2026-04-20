import Foundation
import AIKit

public enum WebTools {
    public static func httpGetTool(session: URLSession = .shared) -> any Tool {
        let spec = ToolSpec(
            name: "http_get",
            description: "Fetch a web URL via HTTP GET and return the response body.",
            parameters: .object(
                properties: [
                    "url": .string(format: "uri"),
                    "max_bytes": .integer(minimum: 1)
                ],
                required: ["url"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let url: String; let max_bytes: Int? }
        struct Out: Encodable {
            let status: Int
            let contentType: String?
            let text: String
            let truncated: Bool
        }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            guard let url = URL(string: args.url) else {
                throw AIError.toolArgumentsInvalid(tool: "http_get", reason: "Invalid URL")
            }
            let (data, response) = try await session.data(from: url)
            let http = response as? HTTPURLResponse
            let limit = args.max_bytes ?? 500_000
            let truncated = data.count > limit
            let sliced = truncated ? data.prefix(limit) : data[...]
            let text = String(decoding: sliced, as: UTF8.self)
            return Out(
                status: http?.statusCode ?? 0,
                contentType: http?.value(forHTTPHeaderField: "Content-Type"),
                text: text,
                truncated: truncated
            )
        }
    }

    public static func webSearchTool(
        session: URLSession = .shared,
        endpoint: URL,
        apiKey: String?,
        builder: @escaping @Sendable (String, Int) -> URLRequest = { query, limit in
            var url = URLComponents(url: URL(string: "https://example.com")!, resolvingAgainstBaseURL: false)!
            url.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "n", value: String(limit))]
            return URLRequest(url: url.url!)
        }
    ) -> any Tool {
        let spec = ToolSpec(
            name: "web_search",
            description: "Perform a web search and return top results.",
            parameters: .object(
                properties: [
                    "query": .string(),
                    "limit": .integer(minimum: 1, maximum: 20)
                ],
                required: ["query"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let query: String; let limit: Int? }
        struct Result: Encodable { let title: String; let url: String; let snippet: String }
        return TypedTool(spec: spec) { (args: Args) async throws -> [Result] in
            var request = builder(args.query, args.limit ?? 5)
            if let apiKey {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            _ = endpoint
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = (json["results"] ?? json["web"]) as? [[String: Any]] else {
                return []
            }
            return items.prefix(args.limit ?? 5).map { item in
                Result(
                    title: (item["title"] as? String) ?? "",
                    url: (item["url"] as? String) ?? "",
                    snippet: (item["snippet"] as? String) ?? (item["description"] as? String) ?? ""
                )
            }
        }
    }
}
