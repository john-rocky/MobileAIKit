import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public extension AIKit {

    // MARK: - Multimodal shortcuts (UIImage / NSImage / CGImage)

    #if canImport(UIKit)
    /// One-line multimodal: pass a `UIImage` and a prompt.
    static func analyzeImage(
        _ image: UIImage,
        prompt: String = "Describe this image.",
        backend: any AIBackend
    ) async throws -> String {
        try await analyzeImage(ImageAttachment(image), prompt: prompt, backend: backend)
    }

    /// One-line batch multimodal over several `UIImage`s.
    static func analyzeImages(
        _ images: [UIImage],
        prompt: String = "Describe these images.",
        backend: any AIBackend
    ) async throws -> String {
        try await analyzeImages(images.map { ImageAttachment($0) }, prompt: prompt, backend: backend)
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    static func analyzeImage(
        _ image: NSImage,
        prompt: String = "Describe this image.",
        backend: any AIBackend
    ) async throws -> String {
        try await analyzeImage(ImageAttachment(image), prompt: prompt, backend: backend)
    }
    #endif

    static func analyzeImage(
        _ cgImage: CGImage,
        prompt: String = "Describe this image.",
        backend: any AIBackend
    ) async throws -> String {
        try await analyzeImage(ImageAttachment(cgImage), prompt: prompt, backend: backend)
    }

    // MARK: - Chat with attachments (ad-hoc multimodal)

    /// Send a prompt plus arbitrary attachments (images, audio, video, PDF, text) in one call.
    static func chat(
        _ prompt: String,
        attachments: [Attachment],
        backend: any AIBackend,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) async throws -> String {
        var messages: [Message] = []
        if let systemPrompt { messages.append(.system(systemPrompt)) }
        messages.append(.user(prompt, attachments: attachments))
        let result = try await backend.generate(messages: messages, tools: [], config: config)
        return result.message.content
    }

    #if canImport(UIKit)
    /// Shortest UIImage multimodal call: `AIKit.chat("What's this?", image: uiImage, backend: backend)`.
    static func chat(
        _ prompt: String,
        image: UIImage,
        backend: any AIBackend,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) async throws -> String {
        try await chat(
            prompt,
            attachments: [.image(ImageAttachment(image))],
            backend: backend,
            systemPrompt: systemPrompt,
            config: config
        )
    }
    #endif
}
