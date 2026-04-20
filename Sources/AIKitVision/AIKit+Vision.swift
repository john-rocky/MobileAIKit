import Foundation
import AIKit

public extension AIKit {
    static func ocr(image: ImageAttachment, languages: [String] = ["en-US", "ja-JP"]) async throws -> OCRResult {
        try await OCR.recognize(in: image, languages: languages)
    }

    static func ocr(fileURL: URL, languages: [String] = ["en-US", "ja-JP"]) async throws -> OCRResult {
        let attachment = ImageAttachment(source: .fileURL(fileURL))
        return try await OCR.recognize(in: attachment, languages: languages)
    }

    static func imageAnalysis(_ image: ImageAttachment) async throws -> ImageAnalysisResult {
        try await ImageAnalysis.analyze(image)
    }
}
