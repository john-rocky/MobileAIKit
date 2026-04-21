import Foundation
import AIKit
#if canImport(UIKit)
import UIKit
#endif

public extension AIKit {
    /// OCR from an ``ImageAttachment``.
    static func ocr(image: ImageAttachment, languages: [String] = ["en-US", "ja-JP"]) async throws -> OCRResult {
        try await OCR.recognize(in: image, languages: languages)
    }

    /// OCR from a local image file.
    static func ocr(fileURL: URL, languages: [String] = ["en-US", "ja-JP"]) async throws -> OCRResult {
        let attachment = ImageAttachment(source: .fileURL(fileURL))
        return try await OCR.recognize(in: attachment, languages: languages)
    }

    #if canImport(UIKit)
    /// One-line OCR from a `UIImage`.
    static func ocr(_ image: UIImage, languages: [String] = ["en-US", "ja-JP"]) async throws -> String {
        try await OCR.recognize(in: ImageAttachment(image), languages: languages).text
    }
    #endif

    /// One-line OCR from a `CGImage`.
    static func ocr(_ image: CGImage, languages: [String] = ["en-US", "ja-JP"]) async throws -> String {
        try await OCR.recognize(in: ImageAttachment(image), languages: languages).text
    }

    /// Vision framework analysis (faces, barcodes, rectangles) from an attachment.
    static func imageAnalysis(_ image: ImageAttachment) async throws -> ImageAnalysisResult {
        try await ImageAnalysis.analyze(image)
    }
}
