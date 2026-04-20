import Foundation

public struct StructuredRequest<T: Decodable & Sendable>: Sendable {
    public let type: T.Type
    public let schema: JSONSchema
    public let instruction: String
    public let examples: [String]

    public init(type: T.Type, schema: JSONSchema, instruction: String, examples: [String] = []) {
        self.type = type
        self.schema = schema
        self.instruction = instruction
        self.examples = examples
    }

    public func systemPrompt() -> String {
        var parts: [String] = []
        parts.append("You must return a single JSON object that conforms to this schema:")
        if let data = try? schema.jsonData(), let s = String(data: data, encoding: .utf8) {
            parts.append(s)
        }
        parts.append("Return only valid JSON. Do not include markdown fences, commentary, or extra text.")
        if !examples.isEmpty {
            parts.append("Examples:")
            parts.append(contentsOf: examples)
        }
        return parts.joined(separator: "\n\n")
    }
}

public extension ChatSession {
    func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        schema: JSONSchema,
        instruction: String,
        input: String
    ) async throws -> T {
        let request = StructuredRequest(type: type, schema: schema, instruction: instruction)
        let previousSystem = self.systemPrompt
        self.systemPrompt = request.systemPrompt()
        defer { self.systemPrompt = previousSystem }

        let previousConfig = self.config
        var strict = self.config
        strict.temperature = 0.1
        strict.topP = 1.0
        self.config = strict
        defer { self.config = previousConfig }

        _ = try await send(input)
        guard let last = messages.last, last.role == .assistant else {
            throw AIError.generationFailed("No assistant response")
        }
        return try StructuredDecoder().decode(type, from: last.content)
    }
}
