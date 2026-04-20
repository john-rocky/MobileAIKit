import Foundation
import AIKit
#if canImport(AIKitVision)
import AIKitVision

enum CameraAssistant {
    static func describePhoto(url: URL, backend: any AIBackend) async throws -> String {
        let attachment = ImageAttachment(source: .fileURL(url))
        let ocr = try await OCR.recognize(in: attachment)
        let analysis = try await ImageAnalysis.analyze(attachment)

        let description = """
        OCR text:
        \(ocr.text.isEmpty ? "(none)" : ocr.text)

        Detected: \(analysis.faces.count) faces, \(analysis.barcodes.count) barcodes, \(analysis.objects.count) rectangles.
        """

        return try await AIKit.chat(
            "Summarise this photo and mention anything notable:\n\n\(description)",
            backend: backend
        )
    }
}
#endif
