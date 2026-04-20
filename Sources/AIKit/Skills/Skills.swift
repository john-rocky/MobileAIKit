import Foundation

public enum SummaryStyle: String, Sendable {
    case oneLine
    case tldr
    case bulletPoints
    case executiveSummary
    case technicalBrief
}

public enum RewriteStyle: String, Sendable {
    case clarify
    case shorten
    case formal
    case casual
    case friendly
    case polite
    case removeJargon
    case keepMeaning
}

public struct Skills {
    public let backend: any AIBackend
    public var config: GenerationConfig

    public init(backend: any AIBackend, config: GenerationConfig = .default) {
        self.backend = backend
        self.config = config
    }

    public func summarize(_ text: String, style: SummaryStyle = .tldr, maxWords: Int = 120) async throws -> String {
        let sys = "You are a concise summarizer."
        let styleHint: String
        switch style {
        case .oneLine: styleHint = "Produce a single-sentence summary."
        case .tldr: styleHint = "Produce a TL;DR in under \(maxWords) words."
        case .bulletPoints: styleHint = "Produce 3-5 bullet points."
        case .executiveSummary: styleHint = "Produce an executive summary with key findings and implications."
        case .technicalBrief: styleHint = "Produce a technical brief with key facts, figures, and caveats."
        }
        return try await AIKit.chat(
            "\(styleHint)\n\n\(text)",
            backend: backend,
            systemPrompt: sys,
            config: config
        )
    }

    public func rewrite(_ text: String, style: RewriteStyle) async throws -> String {
        let sys: String
        switch style {
        case .clarify: sys = "Rewrite to be clearer without changing meaning."
        case .shorten: sys = "Shorten without losing key information."
        case .formal: sys = "Rewrite in a formal register."
        case .casual: sys = "Rewrite in a casual, conversational register."
        case .friendly: sys = "Rewrite to sound warm and friendly."
        case .polite: sys = "Rewrite to sound polite and respectful."
        case .removeJargon: sys = "Remove jargon; explain simply."
        case .keepMeaning: sys = "Rewrite in different words while preserving exact meaning."
        }
        return try await AIKit.chat(text, backend: backend, systemPrompt: sys, config: config)
    }

    public func translate(_ text: String, to locale: String) async throws -> String {
        try await AIKit.chat(
            text,
            backend: backend,
            systemPrompt: "Translate the input into \(locale). Output only the translation, no commentary.",
            config: config
        )
    }

    public func tag(_ text: String, maxTags: Int = 6) async throws -> [String] {
        struct Out: Decodable { let tags: [String] }
        let schema: JSONSchema = .object(
            properties: ["tags": .array(items: .string(), maxItems: maxTags)],
            required: ["tags"]
        )
        let out: Out = try await AIKit.extract(
            Out.self,
            from: text,
            schema: schema,
            instruction: "Produce up to \(maxTags) concise keyword tags that describe the text.",
            backend: backend
        )
        return out.tags
    }

    public func rank(items: [String], by criterion: String) async throws -> [Int] {
        struct Out: Decodable { let order: [Int] }
        let indexedList = items.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "\n")
        let schema: JSONSchema = .object(
            properties: [
                "order": .array(items: .integer(minimum: 0, maximum: items.count - 1))
            ],
            required: ["order"]
        )
        let instruction = "Rank the items by the given criterion. Return 'order' as a list of item indices from best to worst. Criterion: \(criterion)"
        let out: Out = try await AIKit.extract(
            Out.self,
            from: indexedList,
            schema: schema,
            instruction: instruction,
            backend: backend
        )
        return out.order
    }

    public struct ComparisonResult: Decodable, Sendable, Hashable {
        public let similarities: [String]
        public let differences: [String]
        public let verdict: String
    }

    public func compare(_ a: String, _ b: String, criterion: String = "overall quality") async throws -> ComparisonResult {
        let schema: JSONSchema = .object(
            properties: [
                "similarities": .array(items: .string()),
                "differences": .array(items: .string()),
                "verdict": .string()
            ],
            required: ["similarities", "differences", "verdict"]
        )
        let input = "A:\n\(a)\n\nB:\n\(b)\n\nCriterion: \(criterion)"
        return try await AIKit.extract(
            ComparisonResult.self,
            from: input,
            schema: schema,
            instruction: "Compare A and B.",
            backend: backend
        )
    }

    public struct ActionProposal: Decodable, Sendable, Hashable {
        public let title: String
        public let description: String
        public let tool: String?
        public let arguments: [String: String]
        public let requiresApproval: Bool
    }

    public func proposeAction(for request: String, availableTools: [ToolSpec]) async throws -> ActionProposal {
        let toolDump = availableTools.map { "- \($0.name): \($0.description)" }.joined(separator: "\n")
        let schema: JSONSchema = .object(
            properties: [
                "title": .string(),
                "description": .string(),
                "tool": .string(),
                "arguments": .object(properties: [:], required: [], additionalProperties: true),
                "requiresApproval": .boolean()
            ],
            required: ["title", "description", "requiresApproval"]
        )
        let input = "User request: \(request)\n\nAvailable tools:\n\(toolDump)"
        return try await AIKit.extract(
            ActionProposal.self,
            from: input,
            schema: schema,
            instruction: "Pick the best tool (or none), produce arguments as a JSON object of strings.",
            backend: backend
        )
    }
}
