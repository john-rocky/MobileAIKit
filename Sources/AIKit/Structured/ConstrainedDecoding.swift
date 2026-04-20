import Foundation

public struct ConstrainedDecoder: Sendable {
    public let maxAttempts: Int
    public let decoder: StructuredDecoder

    public init(maxAttempts: Int = 3, decoder: StructuredDecoder = .init()) {
        self.maxAttempts = maxAttempts
        self.decoder = decoder
    }

    public func decode<T: Decodable & Sendable>(
        _ type: T.Type,
        schema: JSONSchema,
        backend: any AIBackend,
        messages: [Message]
    ) async throws -> T {
        var transcript = messages
        var lastError: String?
        for attempt in 0..<maxAttempts {
            var config = GenerationConfig.deterministic
            config.maxTokens = 1024
            if attempt == 0 {
                transcript.insert(.system(Self.schemaSystem(schema)), at: 0)
            } else if let lastError {
                transcript.append(.system("Your previous output was invalid. Error: \(lastError). Output valid JSON only."))
            }
            let result = try await backend.generate(messages: transcript, tools: [], config: config)
            do {
                return try decoder.decode(type, from: result.message.content)
            } catch {
                lastError = error.localizedDescription
                transcript.append(result.message)
            }
        }
        throw AIError.decodingFailed(lastError ?? "Unknown")
    }

    static func schemaSystem(_ schema: JSONSchema) -> String {
        let jsonString: String
        if let data = try? schema.jsonData(), let s = String(data: data, encoding: .utf8) {
            jsonString = s
        } else {
            jsonString = ""
        }
        return """
        Respond with a single JSON value matching this JSON Schema:
        \(jsonString)
        Output rules:
        - Only a single JSON value. No markdown fences, no commentary.
        - All required fields must be present.
        - Respect enum values and formats.
        """
    }
}

public struct EnumForcedDecoder<Value: RawRepresentable & CaseIterable & Sendable>: Sendable where Value.RawValue == String {
    public let constrained: ConstrainedDecoder

    public init(constrained: ConstrainedDecoder = .init()) {
        self.constrained = constrained
    }

    public func decode(
        backend: any AIBackend,
        input: String,
        instruction: String
    ) async throws -> Value {
        struct Out: Decodable { let label: String }
        let schema: JSONSchema = .object(
            properties: ["label": .string(enumValues: Array(Value.allCases).map(\.rawValue))],
            required: ["label"]
        )
        let out: Out = try await constrained.decode(
            Out.self,
            schema: schema,
            backend: backend,
            messages: [.user("\(instruction)\n\n\(input)")]
        )
        guard let value = Value(rawValue: out.label) else {
            throw AIError.schemaMismatch("Unknown value '\(out.label)'")
        }
        return value
    }
}
