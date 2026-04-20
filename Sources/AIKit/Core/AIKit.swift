import Foundation

public enum AIKit {
    public static let version = "0.1.0"

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

    @MainActor
    public static func session(
        backend: any AIBackend,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) -> ChatSession {
        ChatSession(backend: backend, systemPrompt: systemPrompt, config: config)
    }

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

    public static func embed(_ text: String, backend: any AIBackend) async throws -> [Float] {
        try await backend.embed(text)
    }
}
