import Foundation

public actor Conversation {
    public private(set) var messages: [Message]
    public let id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        messages: [Message] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
        self.metadata = metadata
    }

    public func append(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
    }

    public func append(contentsOf newMessages: [Message]) {
        messages.append(contentsOf: newMessages)
        updatedAt = Date()
    }

    public func replaceLast(_ message: Message) {
        if messages.isEmpty {
            messages.append(message)
        } else {
            messages[messages.count - 1] = message
        }
        updatedAt = Date()
    }

    public func remove(id: UUID) {
        messages.removeAll { $0.id == id }
        updatedAt = Date()
    }

    public func clear(keepSystem: Bool = true) {
        if keepSystem {
            messages = messages.filter { $0.role == .system }
        } else {
            messages.removeAll()
        }
        updatedAt = Date()
    }

    public func snapshot() -> ConversationSnapshot {
        ConversationSnapshot(
            id: id,
            messages: messages,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public func restore(_ snapshot: ConversationSnapshot) {
        messages = snapshot.messages
        metadata = snapshot.metadata
        createdAt = snapshot.createdAt
        updatedAt = snapshot.updatedAt
    }
}

public struct ConversationSnapshot: Codable, Sendable, Hashable {
    public let id: UUID
    public let messages: [Message]
    public let metadata: [String: String]
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        messages: [Message],
        metadata: [String: String],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.messages = messages
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
