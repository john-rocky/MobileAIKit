import Foundation

fileprivate struct ClassifyOut: Decodable, Sendable {
    let label: String
}

/// Top-level Swift-first entry point for running local AI features.
///
/// `AIKit` exposes simple one-shot helpers (``chat(_:backend:systemPrompt:config:)``,
/// ``stream(_:backend:systemPrompt:config:)``, ``extract(_:from:schema:instruction:backend:)``, …)
/// that work identically across any ``AIBackend``. The bundled runtime is
/// `CoreMLLLMBackend` (in the `AIKitCoreMLLLM` target).
///
/// Use ``ChatSession`` when you need state, tool calls, memory, or retrieval.
public enum AIKit {
    /// Package version string.
    public static let version = "0.1.0"

    /// Generates a complete answer for `prompt` using `backend`.
    /// - Parameters:
    ///   - prompt: User message text.
    ///   - backend: Any ``AIBackend`` instance (e.g. `CoreMLLLMBackend`).
    ///   - systemPrompt: Optional system instruction prepended to the request.
    ///   - config: Generation options. Defaults to ``GenerationConfig/default``.
    /// - Returns: The full assistant text.
    public static func chat(
        _ prompt: String,
        backend: any AIBackend,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) async throws -> String {
        var messages: [Message] = []
        if let systemPrompt { messages.append(.system(systemPrompt)) }
        messages.append(.user(prompt))
        let result = try await backend.generate(messages: messages, tools: [], config: config)
        return result.message.content
    }

    /// Streams deltas for `prompt` as they're produced.
    public static func stream(
        _ prompt: String,
        backend: any AIBackend,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var messages: [Message] = []
                    if let systemPrompt { messages.append(.system(systemPrompt)) }
                    messages.append(.user(prompt))
                    for try await chunk in backend.stream(messages: messages, tools: [], config: config) {
                        if !chunk.delta.isEmpty {
                            continuation.yield(chunk.delta)
                        }
                        if chunk.finished { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Creates an `@Observable` ``ChatSession`` with sensible defaults.
    @MainActor
    public static func session(
        backend: any AIBackend,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) -> ChatSession {
        ChatSession(backend: backend, systemPrompt: systemPrompt, config: config)
    }

    /// Extracts a `Codable` value of `type` from `text`.
    ///
    /// The schema is embedded in the system prompt so the model replies with valid JSON,
    /// which is then repaired (trailing commas / fences removed) before decoding.
    /// When the first output can't be decoded, one "fix the JSON against the schema"
    /// retry is sent to the backend before throwing ``StructuredExtractionError``.
    public static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from text: String,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields.",
        backend: any AIBackend
    ) async throws -> T {
        let systemPrompt = StructuredPromptBuilder.systemPrompt(schema: schema)
        let messages: [Message] = [
            .system(systemPrompt),
            .user("\(instruction)\n\n\(text)")
        ]
        return try await extractWithRepair(
            type,
            baseMessages: messages,
            systemPrompt: systemPrompt,
            backend: backend
        )
    }

    /// Internal helper: first-pass decode, one LLM-repair retry, then throw with raw text preserved.
    static func extractWithRepair<T: Decodable & Sendable>(
        _ type: T.Type,
        baseMessages: [Message],
        systemPrompt: String,
        backend: any AIBackend
    ) async throws -> T {
        var strict = GenerationConfig.default
        strict.temperature = 0.1
        strict.topP = 1.0

        let first = try await backend.generate(messages: baseMessages, config: strict)
        let rawFirst = first.message.content
        let decoder = StructuredDecoder()
        do {
            return try decoder.decode(type, from: rawFirst)
        } catch let firstError {
            let repairMessages: [Message] = baseMessages + [
                first.message,
                .user("""
                Your previous reply could not be parsed as JSON against the schema in the system \
                prompt. Re-emit exactly one valid JSON object that matches the schema. No prose, \
                no markdown fences.
                """)
            ]
            do {
                let second = try await backend.generate(messages: repairMessages, config: strict)
                let rawSecond = second.message.content
                do {
                    return try decoder.decode(type, from: rawSecond)
                } catch let secondError {
                    throw StructuredExtractionError(
                        rawText: rawSecond,
                        underlying: secondError,
                        attempts: 2
                    )
                }
            } catch let error as StructuredExtractionError {
                throw error
            } catch {
                throw StructuredExtractionError(
                    rawText: rawFirst,
                    underlying: firstError,
                    attempts: 1
                )
            }
        }
    }

    /// Classifies `text` into one of `Label`'s cases. `Label.rawValue` must be `String`.
    public static func classify<Label: RawRepresentable & CaseIterable & Sendable>(
        _ text: String,
        labels: Label.Type,
        instruction: String = "Classify the input.",
        backend: any AIBackend
    ) async throws -> Label where Label.RawValue == String {
        let allCases = Array(Label.allCases).map(\.rawValue)
        let schema: JSONSchema = .object(
            properties: ["label": .string(enumValues: allCases)],
            required: ["label"]
        )
        let out: ClassifyOut = try await extract(ClassifyOut.self, from: text, schema: schema, instruction: instruction, backend: backend)
        guard let value = Label(rawValue: out.label) else {
            throw AIError.schemaMismatch("Unknown label '\(out.label)'")
        }
        return value
    }

    /// Returns an embedding vector for `text` if the backend supports ``BackendCapabilities/embeddings``.
    ///
    /// The bundled `CoreMLLLMBackend` does **not** support embeddings — it is a text
    /// generator, not an embedder. For RAG / similarity search, construct a dedicated
    /// `Embedder` (e.g. `HashingEmbedder` for zero-setup, or `NLEmbedder` for higher
    /// quality) and pass it to `RAGPipeline` / `DatabaseMemoryStore` directly rather
    /// than routing through the backend.
    public static func embed(_ text: String, backend: any AIBackend) async throws -> [Float] {
        try await backend.embed(text)
    }

    /// TL;DR-style summary of `text`. See ``SummaryStyle`` for alternatives.
    public static func summarize(
        _ text: String,
        style: SummaryStyle = .tldr,
        backend: any AIBackend
    ) async throws -> String {
        try await Skills(backend: backend).summarize(text, style: style)
    }

    /// Rewrites `text` in the given ``RewriteStyle``.
    public static func rewrite(
        _ text: String,
        style: RewriteStyle,
        backend: any AIBackend
    ) async throws -> String {
        try await Skills(backend: backend).rewrite(text, style: style)
    }

    /// Translates `text` into `locale` (any human-language identifier like `"ja"` or `"fr-CA"`).
    public static func translate(
        _ text: String,
        to locale: String,
        backend: any AIBackend
    ) async throws -> String {
        try await Skills(backend: backend).translate(text, to: locale)
    }

    /// Extracts up to `maxTags` short keyword tags describing `text`.
    public static func tag(
        _ text: String,
        maxTags: Int = 6,
        backend: any AIBackend
    ) async throws -> [String] {
        try await Skills(backend: backend).tag(text, maxTags: maxTags)
    }

    /// Asks the vision-capable `backend` to describe or answer something about `attachment`.
    public static func analyzeImage(
        _ attachment: ImageAttachment,
        prompt: String = "Describe this image.",
        backend: any AIBackend
    ) async throws -> String {
        guard backend.info.capabilities.contains(.vision) else {
            throw AIError.unsupportedCapability("vision")
        }
        let message = Message.user(prompt, attachments: [.image(attachment)])
        let result = try await backend.generate(messages: [message], tools: [], config: .default)
        return result.message.content
    }

    /// Vision prompt across multiple images in one message.
    public static func analyzeImages(
        _ attachments: [ImageAttachment],
        prompt: String = "Describe these images.",
        backend: any AIBackend
    ) async throws -> String {
        guard backend.info.capabilities.contains(.vision) else {
            throw AIError.unsupportedCapability("vision")
        }
        let atts = attachments.map { Attachment.image($0) }
        let message = Message.user(prompt, attachments: atts)
        let result = try await backend.generate(messages: [message], tools: [], config: .default)
        return result.message.content
    }

    /// Vision prompt over a local video (sampling happens in the backend if supported).
    public static func analyzeVideo(
        _ attachment: VideoAttachment,
        prompt: String = "Describe this video.",
        backend: any AIBackend
    ) async throws -> String {
        let message = Message.user(prompt, attachments: [.video(attachment)])
        let result = try await backend.generate(messages: [message], tools: [], config: .default)
        return result.message.content
    }

    /// Runs a tool-calling loop until the model produces a plain text answer or iteration cap (8) hits.
    public static func askWithTools(
        _ prompt: String,
        tools: ToolRegistry,
        backend: any AIBackend,
        systemPrompt: String? = nil
    ) async throws -> String {
        let specs = await tools.specs()
        var messages: [Message] = []
        if let systemPrompt { messages.append(.system(systemPrompt)) }
        messages.append(.user(prompt))
        var iteration = 0
        while iteration < 8 {
            iteration += 1
            let result = try await backend.generate(messages: messages, tools: specs, config: .default)
            messages.append(result.message)
            if result.message.toolCalls.isEmpty { return result.message.content }
            let toolMessages = try await tools.executeAll(calls: result.message.toolCalls)
            messages.append(contentsOf: toolMessages)
        }
        throw AIError.generationFailed("Too many tool iterations")
    }
}
