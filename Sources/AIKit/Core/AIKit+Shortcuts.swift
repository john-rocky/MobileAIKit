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

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    static func chat(
        _ prompt: String,
        image: NSImage,
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

    /// Platform-agnostic multimodal chat taking a prepared ``ImageAttachment``.
    static func chat(
        _ prompt: String,
        image: ImageAttachment,
        backend: any AIBackend,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) async throws -> String {
        try await chat(
            prompt,
            attachments: [.image(image)],
            backend: backend,
            systemPrompt: systemPrompt,
            config: config
        )
    }

    // MARK: - Multimodal structured extraction

    /// Extract a `Codable` value directly from an image (e.g. food photo → ``Nutrition``,
    /// receipt → line items, business card → `Contact`). Fails loudly when the backend
    /// lacks ``BackendCapabilities/vision``. Throws ``StructuredExtractionError`` on
    /// decode failure so callers can log / show the raw model output.
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from image: ImageAttachment,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend
    ) async throws -> T {
        guard backend.info.capabilities.contains(.vision) else {
            throw AIError.unsupportedCapability("vision")
        }
        let systemPrompt = StructuredRequest.systemPrompt(schema: schema)
        let base: [Message] = [
            .system(systemPrompt),
            .user(instruction, attachments: [.image(image)])
        ]
        return try await extractWithRepair(
            type, baseMessages: base, systemPrompt: systemPrompt, backend: backend
        )
    }

    /// Extract from multiple images in one call (e.g. front + back of a label).
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from images: [ImageAttachment],
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the images.",
        backend: any AIBackend
    ) async throws -> T {
        guard backend.info.capabilities.contains(.vision) else {
            throw AIError.unsupportedCapability("vision")
        }
        let systemPrompt = StructuredRequest.systemPrompt(schema: schema)
        let atts = images.map { Attachment.image($0) }
        let base: [Message] = [
            .system(systemPrompt),
            .user(instruction, attachments: atts)
        ]
        return try await extractWithRepair(
            type, baseMessages: base, systemPrompt: systemPrompt, backend: backend
        )
    }

    #if canImport(UIKit)
    /// `UIImage` convenience over ``extract(_:from:schema:instruction:backend:)-1``.
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from image: UIImage,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend
    ) async throws -> T {
        try await extract(
            type,
            from: ImageAttachment(image),
            schema: schema,
            instruction: instruction,
            backend: backend
        )
    }
    #endif

    /// Raw-bytes convenience: JPEG/PNG `Data` straight from the camera or
    /// `PhotosPickerItem.loadTransferable(type: Data.self)`.
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from imageData: Data,
        mimeType: String = "image/jpeg",
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend
    ) async throws -> T {
        let attachment = ImageAttachment(source: .data(imageData), mimeType: mimeType)
        return try await extract(
            type,
            from: attachment,
            schema: schema,
            instruction: instruction,
            backend: backend
        )
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from image: NSImage,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend
    ) async throws -> T {
        try await extract(
            type,
            from: ImageAttachment(image),
            schema: schema,
            instruction: instruction,
            backend: backend
        )
    }
    #endif

    // MARK: - Streaming extraction

    /// Extraction with a live delta handler — called for each token so the UI can show
    /// the model's output as it arrives instead of a dead spinner during a 10–30 s VLM run.
    /// The final decoded value is returned; repair retry still kicks in on decode failure.
    ///
    /// - Important: `onDelta` is invoked on the executor the backend's ``AIBackend/stream(messages:tools:config:)``
    ///   emits from — typically a background task, *not* the main actor. Hop to your UI actor
    ///   (e.g. `Task { @MainActor in … }`) before mutating `@State`/`@Observable` properties.
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from image: ImageAttachment,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> T {
        guard backend.info.capabilities.contains(.vision) else {
            throw AIError.unsupportedCapability("vision")
        }
        let systemPrompt = StructuredRequest.systemPrompt(schema: schema)
        let base: [Message] = [
            .system(systemPrompt),
            .user(instruction, attachments: [.image(image)])
        ]
        var strict = GenerationConfig.default
        strict.temperature = 0.1
        strict.topP = 1.0

        var buffer = ""
        for try await chunk in backend.stream(messages: base, config: strict) {
            if !chunk.delta.isEmpty {
                buffer += chunk.delta
                onDelta(chunk.delta)
            }
            if chunk.finished { break }
        }

        do {
            return try StructuredDecoder().decode(type, from: buffer)
        } catch {
            let assistantEcho = Message.assistant(buffer)
            let repairMessages = base + [
                assistantEcho,
                .user("""
                Your previous reply could not be parsed as JSON against the schema in the system \
                prompt. Re-emit exactly one valid JSON object that matches the schema. No prose, \
                no markdown fences.
                """)
            ]
            do {
                let second = try await backend.generate(messages: repairMessages, config: strict)
                return try StructuredDecoder().decode(type, from: second.message.content)
            } catch let secondError {
                throw StructuredExtractionError(
                    rawText: buffer,
                    underlying: secondError,
                    attempts: 2
                )
            }
        }
    }

    #if canImport(UIKit)
    /// `UIImage` convenience over the streaming extract path.
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from image: UIImage,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> T {
        try await extract(
            type,
            from: ImageAttachment(image),
            schema: schema,
            instruction: instruction,
            backend: backend,
            onDelta: onDelta
        )
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from image: NSImage,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> T {
        try await extract(
            type,
            from: ImageAttachment(image),
            schema: schema,
            instruction: instruction,
            backend: backend,
            onDelta: onDelta
        )
    }
    #endif

    /// Raw-bytes streaming extract — JPEG/PNG `Data` straight from the camera.
    static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from imageData: Data,
        mimeType: String = "image/jpeg",
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> T {
        try await extract(
            type,
            from: ImageAttachment(source: .data(imageData), mimeType: mimeType),
            schema: schema,
            instruction: instruction,
            backend: backend,
            onDelta: onDelta
        )
    }

    /// Streaming raw deltas + final decoded value as an ``AsyncThrowingStream``.
    /// Use when you want to `for await` tokens and receive the typed value at the end.
    static func streamingExtract<T: Decodable & Sendable>(
        _ type: T.Type,
        from image: ImageAttachment,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields from the image.",
        backend: any AIBackend
    ) -> AsyncThrowingStream<StreamingExtractionEvent<T>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let value = try await extract(
                        type,
                        from: image,
                        schema: schema,
                        instruction: instruction,
                        backend: backend
                    ) { delta in
                        continuation.yield(.delta(delta))
                    }
                    continuation.yield(.value(value))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Event produced by ``AIKit/streamingExtract(_:from:schema:instruction:backend:)``.
public enum StreamingExtractionEvent<T: Sendable>: Sendable {
    case delta(String)
    case value(T)
}
