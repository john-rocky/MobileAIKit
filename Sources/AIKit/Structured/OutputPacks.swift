import Foundation

/// Generic checklist output with optional categories.
public struct ChecklistOutput: Codable, Sendable, Hashable {
    public struct Item: Codable, Sendable, Hashable, Identifiable {
        public var id: String { title }
        public let title: String
        public let detail: String?
        public let category: String?
        public let importance: Double?
    }
    public let title: String
    public let items: [Item]

    public static let schema: JSONSchema = .object(
        properties: [
            "title": .string(),
            "items": .array(items: .object(
                properties: [
                    "title": .string(),
                    "detail": .string(),
                    "category": .string(),
                    "importance": .number(minimum: 0, maximum: 1)
                ],
                required: ["title"]
            ))
        ],
        required: ["title", "items"]
    )
}

/// Timeline entries with timestamped events.
public struct TimelineOutput: Codable, Sendable, Hashable {
    public struct Event: Codable, Sendable, Hashable, Identifiable {
        public var id: String { "\(timestamp)-\(title)" }
        public let timestamp: String
        public let title: String
        public let description: String?
        public let category: String?
    }
    public let title: String
    public let events: [Event]

    public static let schema: JSONSchema = .object(
        properties: [
            "title": .string(),
            "events": .array(items: .object(
                properties: [
                    "timestamp": .string(description: "ISO8601 or natural-language timestamp"),
                    "title": .string(),
                    "description": .string(),
                    "category": .string()
                ],
                required: ["timestamp", "title"]
            ))
        ],
        required: ["title", "events"]
    )
}

/// Card layout (title, subtitle, key/value rows, tags, action).
public struct CardOutput: Codable, Sendable, Hashable {
    public struct Row: Codable, Sendable, Hashable, Identifiable {
        public var id: String { label }
        public let label: String
        public let value: String
    }
    public struct Action: Codable, Sendable, Hashable {
        public let label: String
        public let kind: String
        public let payload: [String: String]
    }
    public let title: String
    public let subtitle: String?
    public let rows: [Row]
    public let tags: [String]
    public let primaryAction: Action?

    public static let schema: JSONSchema = .object(
        properties: [
            "title": .string(),
            "subtitle": .string(),
            "rows": .array(items: .object(
                properties: ["label": .string(), "value": .string()],
                required: ["label", "value"]
            )),
            "tags": .array(items: .string()),
            "primaryAction": .object(
                properties: [
                    "label": .string(),
                    "kind": .string(),
                    "payload": .object(properties: [:], required: [], additionalProperties: true)
                ],
                required: ["label", "kind"]
            )
        ],
        required: ["title", "rows", "tags"]
    )
}

/// Graph output with nodes and directed edges.
public struct GraphOutput: Codable, Sendable, Hashable {
    public struct Node: Codable, Sendable, Hashable, Identifiable {
        public let id: String
        public let label: String
        public let group: String?
    }
    public struct Edge: Codable, Sendable, Hashable {
        public let from: String
        public let to: String
        public let label: String?
    }
    public let nodes: [Node]
    public let edges: [Edge]

    public static let schema: JSONSchema = .object(
        properties: [
            "nodes": .array(items: .object(
                properties: ["id": .string(), "label": .string(), "group": .string()],
                required: ["id", "label"]
            )),
            "edges": .array(items: .object(
                properties: ["from": .string(), "to": .string(), "label": .string()],
                required: ["from", "to"]
            ))
        ],
        required: ["nodes", "edges"]
    )
}

public extension Skills {
    func checklist(from text: String, title: String = "Checklist") async throws -> ChecklistOutput {
        try await AIKit.extract(
            ChecklistOutput.self,
            from: text,
            schema: ChecklistOutput.schema,
            instruction: "Produce a checklist titled '\(title)' from the input.",
            backend: backend
        )
    }

    func timeline(from text: String, title: String = "Timeline") async throws -> TimelineOutput {
        try await AIKit.extract(
            TimelineOutput.self,
            from: text,
            schema: TimelineOutput.schema,
            instruction: "Produce a chronological timeline titled '\(title)'.",
            backend: backend
        )
    }

    func card(from text: String) async throws -> CardOutput {
        try await AIKit.extract(
            CardOutput.self,
            from: text,
            schema: CardOutput.schema,
            instruction: "Summarise the input as a card with rows and tags.",
            backend: backend
        )
    }

    func graph(from text: String) async throws -> GraphOutput {
        try await AIKit.extract(
            GraphOutput.self,
            from: text,
            schema: GraphOutput.schema,
            instruction: "Extract a knowledge graph: nodes and edges with labels.",
            backend: backend
        )
    }
}
