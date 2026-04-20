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

}
