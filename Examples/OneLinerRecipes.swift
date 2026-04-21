import Foundation
import AIKit
import AIKitCoreMLLLM
import AIKitVision
import AIKitIntegration
#if canImport(UIKit)
import UIKit
#endif

enum OneLinerRecipes {

    // MARK: - Multimodal (1 line, UIImage + text)

    #if canImport(UIKit)
    static func describe(_ image: UIImage) async throws -> String {
        try await AIKit.chat("Describe this image.", image: image, backend: CoreMLLLMBackend(model: .gemma4e2b))
    }

    static func vqa(_ image: UIImage, question: String) async throws -> String {
        try await AIKit.chat(question, image: image, backend: CoreMLLLMBackend(model: .gemma4e2b))
    }

    static func ocrQuick(_ image: UIImage) async throws -> String {
        try await AIKit.ocr(image)
    }
    #endif

    // MARK: - Web search (1 line)

    static func webAnswer(_ question: String) async throws -> String {
        try await AIKit.askWeb(question, backend: CoreMLLLMBackend(model: .gemma4e2b))
    }

    static func agenticWebAnswer(_ question: String) async throws -> String {
        try await AIKit.askWithWebTools(question, backend: CoreMLLLMBackend(model: .gemma4e2b))
    }

    static func topResults(_ query: String) async throws -> [WebSearchResult] {
        try await AIKit.searchWeb(query)
    }

    // MARK: - Voice (1 line each)

    #if canImport(AVFoundation)
    @MainActor static func speak(_ text: String, language: String = "ja") async {
        await AIKit.speak(text, locale: Locale(identifier: language))
    }
    #endif

    #if canImport(Speech)
    static func transcribeFile(_ audio: AudioAttachment) async throws -> String {
        try await AIKit.transcribe(audio: audio)
    }
    #endif

    // MARK: - PDF (1 line)

    static func pdfQA(_ pdfURL: URL, question: String) async throws -> String {
        try await AIKit.askPDF(question, pdfURL: pdfURL, backend: CoreMLLLMBackend(model: .gemma4e2b))
    }
}
