import Foundation
import AIKit
#if canImport(PDFKit)
import PDFKit
#endif

/// Renders non-native attachments (PDF, text, generic files) into text that
/// can be appended to the user message before sending it to CoreML-LLM.
///
/// Gemma 4 E2B natively ingests only images and audio at the model level, so
/// PDFs and plain files would otherwise be silently dropped by `prepare`.
/// This helper extracts their textual content, clips it to a budget that
/// leaves room for the user's actual prompt, and formats it with clear
/// delimiters so the model can reason about it.
///
/// Budgets default to ~4 KB per attachment and ~12 KB total (well under the
/// 8192-token context — ~3 chars/token for typical prose). Callers can
/// override via `CoreMLLLMBackend.attachmentIngestionOptions`.
public struct AttachmentIngestionOptions: Sendable {
    /// Max characters to extract from a single attachment.
    public var perAttachmentCharLimit: Int
    /// Max characters aggregated across all attachments in one message.
    public var totalCharLimit: Int
    /// When a file's bytes can't be decoded as UTF-8, include a short
    /// stub mentioning the filename/mime so the model sees the attempt.
    public var acknowledgeBinaryFiles: Bool

    public init(
        perAttachmentCharLimit: Int = 4_000,
        totalCharLimit: Int = 12_000,
        acknowledgeBinaryFiles: Bool = true
    ) {
        self.perAttachmentCharLimit = perAttachmentCharLimit
        self.totalCharLimit = totalCharLimit
        self.acknowledgeBinaryFiles = acknowledgeBinaryFiles
    }

    public static let `default` = AttachmentIngestionOptions()
}

enum AttachmentIngestion {

    /// Pulls `.text`, `.pdf`, and text-decodable `.file` attachments off every
    /// message, renders them, and splices the rendered text into the message's
    /// `content`. `.image`, `.audio`, `.video` are passed through untouched so
    /// the native CoreML-LLM pipeline still sees them.
    static func expand(
        messages: [Message],
        options: AttachmentIngestionOptions
    ) -> [Message] {
        guard messages.contains(where: { hasTextualAttachment($0) }) else {
            return messages
        }
        var result: [Message] = []
        result.reserveCapacity(messages.count)
        for message in messages {
            result.append(expand(message, options: options))
        }
        return result
    }

    // MARK: - Internal

    private static func hasTextualAttachment(_ message: Message) -> Bool {
        message.attachments.contains { att in
            switch att {
            case .pdf, .text, .file: return true
            default: return false
            }
        }
    }

    private static func expand(_ message: Message, options: AttachmentIngestionOptions) -> Message {
        var preservedAttachments: [Attachment] = []
        var renderedBlocks: [String] = []
        var budget = options.totalCharLimit
        for att in message.attachments {
            switch att {
            case .image, .audio, .video:
                // Preserved — handled natively by `CoreMLLLMBackend.prepare`.
                preservedAttachments.append(att)
            case .text(let t):
                guard budget > 0 else { continue }
                if let block = renderText(t, budget: min(options.perAttachmentCharLimit, budget)) {
                    renderedBlocks.append(block)
                    budget -= block.count
                }
            case .pdf(let p):
                guard budget > 0 else { continue }
                if let block = renderPDF(p, budget: min(options.perAttachmentCharLimit, budget)) {
                    renderedBlocks.append(block)
                    budget -= block.count
                }
            case .file(let f):
                guard budget > 0 else { continue }
                if let block = renderFile(f, budget: min(options.perAttachmentCharLimit, budget), acknowledgeBinary: options.acknowledgeBinaryFiles) {
                    renderedBlocks.append(block)
                    budget -= block.count
                }
            }
        }
        guard !renderedBlocks.isEmpty else { return message }
        let suffix = renderedBlocks.joined(separator: "\n\n")
        let newContent: String
        if message.content.isEmpty {
            newContent = suffix
        } else {
            newContent = message.content + "\n\n" + suffix
        }
        return Message(
            id: message.id,
            role: message.role,
            content: newContent,
            attachments: preservedAttachments,
            toolCalls: message.toolCalls,
            toolCallId: message.toolCallId,
            name: message.name,
            createdAt: message.createdAt
        )
    }

    private static func renderText(_ attachment: TextAttachment, budget: Int) -> String? {
        guard budget > 0 else { return nil }
        let body = truncate(attachment.text, to: budget)
        let header = attachment.title.map { "[attached text: \($0)]" } ?? "[attached text]"
        return header + "\n---\n" + body + "\n---"
    }

    private static func renderPDF(_ attachment: PDFAttachment, budget: Int) -> String? {
        guard budget > 0 else { return nil }
        #if canImport(PDFKit)
        guard let doc = PDFDocument(url: attachment.fileURL) else {
            return "[attached PDF (\(attachment.fileURL.lastPathComponent)) could not be opened]"
        }
        let pageCount = doc.pageCount
        guard pageCount > 0 else {
            return "[attached PDF (\(attachment.fileURL.lastPathComponent)): empty]"
        }
        let range: ClosedRange<Int>
        if let pr = attachment.pageRange {
            range = max(0, pr.lowerBound)...min(pageCount - 1, pr.upperBound)
        } else {
            range = 0...(pageCount - 1)
        }
        var extracted = ""
        pageLoop: for i in range {
            guard let page = doc.page(at: i), let text = page.string else { continue }
            let prefix = "[page \(i + 1)]\n"
            if extracted.count + prefix.count + text.count > budget {
                let remaining = max(0, budget - extracted.count - prefix.count)
                if remaining > 0 {
                    extracted += prefix + String(text.prefix(remaining)) + "\n…"
                }
                break pageLoop
            }
            extracted += prefix + text + "\n"
        }
        let clean = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return "[attached PDF (\(attachment.fileURL.lastPathComponent)): no extractable text — likely scanned images]"
        }
        return "[attached PDF: \(attachment.fileURL.lastPathComponent), pages \(range.lowerBound + 1)–\(range.upperBound + 1)]\n---\n\(clean)\n---"
        #else
        return "[attached PDF (\(attachment.fileURL.lastPathComponent)) — PDFKit not available on this platform, content not extracted]"
        #endif
    }

    private static func renderFile(
        _ attachment: FileAttachment,
        budget: Int,
        acknowledgeBinary: Bool
    ) -> String? {
        guard budget > 0 else { return nil }
        let url = attachment.fileURL
        let name = url.lastPathComponent
        // Route PDFs through the PDF path even when wrapped in FileAttachment.
        if attachment.mimeType.lowercased() == "application/pdf" || url.pathExtension.lowercased() == "pdf" {
            return renderPDF(PDFAttachment(fileURL: url), budget: budget)
        }
        // Try UTF-8. Anything that decodes cleanly (text/*, json, xml, yaml,
        // csv, swift, py, md, log…) will succeed without us having to whitelist.
        guard let data = try? Data(contentsOf: url) else {
            return "[attached file: \(name) — could not read bytes]"
        }
        if let decoded = String(data: data, encoding: .utf8) {
            let body = truncate(decoded, to: budget)
            return "[attached file: \(name), \(attachment.mimeType)]\n---\n\(body)\n---"
        }
        if acknowledgeBinary {
            return "[attached binary file: \(name), \(attachment.mimeType), \(data.count) bytes — content not decoded as text]"
        }
        return nil
    }

    private static func truncate(_ text: String, to budget: Int) -> String {
        guard text.count > budget else { return text }
        return String(text.prefix(budget)) + "\n…"
    }
}
