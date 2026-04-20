import Foundation
import AIKit
#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(PDFKit)
public enum PDFExtractor {
    public struct PageText: Sendable, Hashable, Codable {
        public let pageNumber: Int
        public let text: String
    }

    public static func extractText(from url: URL, pageRange: ClosedRange<Int>? = nil) async throws -> [PageText] {
        guard let document = PDFDocument(url: url) else {
            throw AIError.invalidAttachment("Unable to open PDF at \(url.lastPathComponent)")
        }
        let range: ClosedRange<Int>
        if let pr = pageRange {
            range = max(0, pr.lowerBound)...min(document.pageCount - 1, pr.upperBound)
        } else {
            range = 0...(document.pageCount - 1)
        }
        var results: [PageText] = []
        for i in range {
            if let page = document.page(at: i), let text = page.string {
                results.append(PageText(pageNumber: i + 1, text: text))
            }
        }
        return results
    }

    public static func extractFullText(from url: URL) async throws -> String {
        let pages = try await extractText(from: url)
        return pages.map(\.text).joined(separator: "\n\n")
    }

    public static func asDocument(url: URL) async throws -> Document {
        let text = try await extractFullText(from: url)
        return Document(source: url.lastPathComponent, text: text, metadata: ["type": "pdf", "path": url.path])
    }

    public static func readerTool() -> any Tool {
        let spec = ToolSpec(
            name: "read_pdf",
            description: "Extract text from a PDF file by page range.",
            parameters: .object(
                properties: [
                    "file_path": .string(),
                    "from_page": .integer(minimum: 1),
                    "to_page": .integer(minimum: 1)
                ],
                required: ["file_path"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let file_path: String; let from_page: Int?; let to_page: Int? }
        return TypedTool(spec: spec) { (args: Args) async throws -> [PageText] in
            let url = URL(fileURLWithPath: args.file_path)
            let from = (args.from_page ?? 1) - 1
            let to = (args.to_page ?? Int.max) - 1
            let range = from...to
            return try await extractText(from: url, pageRange: range)
        }
    }
}
#endif
