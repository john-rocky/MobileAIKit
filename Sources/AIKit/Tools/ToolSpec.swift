import Foundation

public struct ToolSpec: Sendable, Hashable, Codable {
    public let name: String
    public let description: String
    public let parameters: JSONSchema
    public let requiresApproval: Bool
    public let sideEffectFree: Bool
    public let timeout: TimeInterval?

    public init(
        name: String,
        description: String,
        parameters: JSONSchema,
        requiresApproval: Bool = false,
        sideEffectFree: Bool = true,
        timeout: TimeInterval? = 30
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.requiresApproval = requiresApproval
        self.sideEffectFree = sideEffectFree
        self.timeout = timeout
    }

    public func openAIJSON() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters.toAny()
            ]
        ]
    }
}
