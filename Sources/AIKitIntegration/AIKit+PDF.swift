import Foundation
import AIKit

#if canImport(PDFKit)
public extension AIKit {
    static func readPDF(_ url: URL) async throws -> String {
        try await PDFExtractor.extractFullText(from: url)
    }

    static func askPDF(_ question: String, pdfURL: URL, backend: any AIBackend) async throws -> String {
        let text = try await PDFExtractor.extractFullText(from: pdfURL)
        let embedder = HashingEmbedder(dimension: 384)
        let rag = RAGPipeline(embedder: embedder)
        try await rag.ingest(text: text, source: pdfURL.lastPathComponent)
        let answer = try await rag.ask(question, backend: backend)
        return answer.answer
    }
}
#endif
