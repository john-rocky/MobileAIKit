import Foundation

/// Top-level Swift-first entry point for running local AI features.
///
/// `AIKit` exposes simple one-shot helpers (``chat(_:backend:systemPrompt:config:)``,
/// ``stream(_:backend:systemPrompt:config:)``, ``extract(_:from:schema:instruction:backend:)``, …)
/// that work identically across every bundled ``AIBackend`` (CoreML-LLM, MLX, llama.cpp,
/// Apple Foundation Models, generic CoreML).
///
/// Use ``ChatSession`` when you need state, tool calls, memory, or retrieval.
public enum AIKit {
    /// Package version string.
    public static let version = "0.1.0"

    /// Generates a complete answer for `prompt` using `backend`.
    /// - Parameters:
    ///   - prompt: User message text.
    ///   - backend: Any ``AIBackend`` instance (e.g. `LlamaCppBackend`).
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
    public static func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from text: String,
        schema: JSONSchema,
        instruction: String = "Extract the requested fields.",
        backend: any AIBackend
    ) async throws -> T {
        let request = StructuredRequest(type: type, schema: schema, instruction: instruction)
        let messages: [Message] = [
            .system(request.systemPrompt()),
            .user("\(instruction)\n\n\(text)")
        ]
        var strict = GenerationConfig.default
        strict.temperature = 0.1
        strict.topP = 1.0
        let result = try await backend.generate(messages: messages, tools: [], config: strict)
        return try StructuredDecoder().decode(type, from: result.message.content)
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
        struct Out: Decodable { let label: String }
        let out: Out = try await extract(Out.self, from: text, schema: schema, instruction: instruction, backend: backend)
        guard let value = Label(rawValue: out.label) else {
            throw AIError.schemaMismatch("Unknown label '\(out.label)'")
        }
        return value
    }

    /// Returns an embedding vector for `text` if the backend supports ``BackendCapabilities/embeddings``.
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
