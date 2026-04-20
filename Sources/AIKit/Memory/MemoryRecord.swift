import Foundation

public enum MemoryKind: String, Sendable, Codable, Hashable {
    case shortTerm
    case longTerm
    case summary
    case entity
    case pinned
    case semantic
    case episodic
    case user
    case workflow
}

public struct MemoryRecord: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public var kind: MemoryKind
    public var namespace: String
    public var text: String
    public var entities: [String]
    public var importance: Double
    public var embedding: [Float]?
    public var expiresAt: Date?
    public var createdAt: Date
    public var accessedAt: Date
    public var source: String?
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        kind: MemoryKind,
        namespace: String = "default",
        text: String,
        entities: [String] = [],
        importance: Double = 0.5,
        embedding: [Float]? = nil,
        expiresAt: Date? = nil,
        createdAt: Date = Date(),
        accessedAt: Date = Date(),
        source: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.namespace = namespace
        self.text = text
        self.entities = entities
        self.importance = importance
        self.embedding = embedding
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.accessedAt = accessedAt
        self.source = source
        self.metadata = metadata
    }

    public var isExpired: Bool {
        guard let e = expiresAt else { return false }
        return Date() > e
    }
}
