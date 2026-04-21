import Foundation
import AIKit

public struct WebPage: Sendable, Hashable, Codable {
    public let url: String
    public let title: String
    public let text: String
    public let links: [String]
}

public enum WebPageReader {
    public static func fetch(url: URL, session: URLSession = .shared) async throws -> WebPage {
        var request = URLRequest(url: url)
        request.setValue("LocalAIKit/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIError.networkUnavailable
        }
        let html = String(decoding: data, as: UTF8.self)
        let title = extractTitle(html: html)
        let text = extractText(html: html)
        let links = extractLinks(html: html, baseURL: url)
        return WebPage(url: url.absoluteString, title: title, text: text, links: links)
    }

    public static func readerTool(session: URLSession = .shared) -> any Tool {
        let spec = ToolSpec(
            name: "read_web_page",
            description: "Fetch a web page and return cleaned text.",
            parameters: .object(
                properties: ["url": .string(format: "uri")],
                required: ["url"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let url: String }
        return TypedTool(spec: spec) { (args: Args) async throws -> WebPage in
            guard let url = URL(string: args.url) else {
                throw AIError.toolArgumentsInvalid(tool: "read_web_page", reason: "Invalid URL")
            }
            return try await fetch(url: url, session: session)
        }
    }

    static func extractTitle(html: String) -> String {
        if let r = html.range(of: "<title>([\\s\\S]*?)</title>", options: [.regularExpression, .caseInsensitive]) {
            let match = String(html[r])
            let stripped = match.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    static func extractText(html: String) -> String {
        var cleaned = html
        for tag in ["script", "style", "noscript", "svg", "header", "footer", "nav"] {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            cleaned = cleaned.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        cleaned = cleaned.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        cleaned = cleaned.replacingOccurrences(of: "</p>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
        cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\n\\s*\n+", with: "\n\n", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractLinks(html: String, baseURL: URL) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "href=\"([^\"]+)\"") else { return [] }
        let ns = html as NSString
        var results: Set<String> = []
        for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let href = ns.substring(with: m.range(at: 1))
            if href.hasPrefix("http") {
                results.insert(href)
            } else if href.hasPrefix("/") {
                if let combined = URL(string: href, relativeTo: baseURL) {
                    results.insert(combined.absoluteString)
                }
            }
        }
        return Array(results.prefix(50))
    }
}
