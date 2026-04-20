import Foundation

public enum DocumentLoader {
    public static func loadText(from url: URL) async throws -> Document {
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        return Document(source: url.lastPathComponent, text: text, metadata: ["path": url.path])
    }

    public static func load(from urls: [URL]) async throws -> [Document] {
        var docs: [Document] = []
        for url in urls {
            if let doc = try? await load(from: url) {
                docs.append(doc)
            }
        }
        return docs
    }

    public static func load(from url: URL) async throws -> Document {
        switch url.pathExtension.lowercased() {
        case "txt", "md", "markdown", "rtf", "json", "yaml", "yml", "csv", "tsv", "log", "swift", "py", "ts", "js":
            return try await loadText(from: url)
        default:
            return try await loadText(from: url)
        }
    }
}
