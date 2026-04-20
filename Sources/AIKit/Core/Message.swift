import Foundation

public enum Role: String, Codable, Sendable, Hashable {
    case system
    case user
    case assistant
    case tool
}

public struct Message: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public var role: Role
    public var content: String
    public var attachments: [Attachment]
    public var toolCalls: [ToolCall]
    public var toolCallId: String?
    public var name: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        attachments: [Attachment] = [],
        toolCalls: [ToolCall] = [],
        toolCallId: String? = nil,
        name: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.attachments = attachments
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.name = name
        self.createdAt = createdAt
    }

    public static func system(_ text: String) -> Message {
        Message(role: .system, content: text)
    }

    public static func user(_ text: String, attachments: [Attachment] = []) -> Message {
        Message(role: .user, content: text, attachments: attachments)
    }

    public static func assistant(_ text: String, toolCalls: [ToolCall] = []) -> Message {
        Message(role: .assistant, content: text, toolCalls: toolCalls)
    }

    public static func tool(_ text: String, toolCallId: String, name: String) -> Message {
        Message(role: .tool, content: text, toolCallId: toolCallId, name: name)
    }
}

public struct ToolCall: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}
