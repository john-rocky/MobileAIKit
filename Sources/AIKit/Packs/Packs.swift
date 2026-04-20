import Foundation

public struct PromptTemplatePack: Sendable, Codable {
    public let name: String
    public let systemPrompt: String
    public let userPromptTemplate: String
    public let config: GenerationConfig
    public let tags: [String]

    public init(
        name: String,
        systemPrompt: String,
        userPromptTemplate: String,
        config: GenerationConfig = .default,
        tags: [String] = []
    ) {
        self.name = name
        self.systemPrompt = systemPrompt
        self.userPromptTemplate = userPromptTemplate
        self.config = config
        self.tags = tags
    }

    public func render(with inputs: [String: String]) -> String {
        var rendered = userPromptTemplate
        for (k, v) in inputs {
            rendered = rendered.replacingOccurrences(of: "{{\(k)}}", with: v)
        }
        return rendered
    }
}

public struct SystemProfile: Sendable, Codable {
    public let name: String
    public let systemPrompt: String
    public let config: GenerationConfig
    public let tools: [String]

    public init(name: String, systemPrompt: String, config: GenerationConfig = .default, tools: [String] = []) {
        self.name = name
        self.systemPrompt = systemPrompt
        self.config = config
        self.tools = tools
    }
}

public struct ToolBundle: Sendable {
    public let name: String
    public let tools: [any Tool]

    public init(name: String, tools: [any Tool]) {
        self.name = name
        self.tools = tools
    }
}

public struct RetrievalPolicyPack: Sendable {
    public let name: String
    public let chunker: Chunker
    public let retrievalLimit: Int
    public let vectorWeight: Float
    public let contextBudgetChars: Int

    public init(
        name: String,
        chunker: Chunker = Chunker(),
        retrievalLimit: Int = 6,
        vectorWeight: Float = 0.7,
        contextBudgetChars: Int = 6_000
    ) {
        self.name = name
        self.chunker = chunker
        self.retrievalLimit = retrievalLimit
        self.vectorWeight = vectorWeight
        self.contextBudgetChars = contextBudgetChars
    }
}

public enum BuiltInPacks {
    public static let concise = SystemProfile(
        name: "concise",
        systemPrompt: "Reply concisely. Prefer 1-3 sentences unless depth is requested.",
        config: GenerationConfig(maxTokens: 256, temperature: 0.4)
    )

    public static let teacher = SystemProfile(
        name: "teacher",
        systemPrompt: "You are a patient teacher. Explain step-by-step with examples and simple language.",
        config: GenerationConfig(maxTokens: 768, temperature: 0.6)
    )

    public static let swiftCoder = SystemProfile(
        name: "swift-coder",
        systemPrompt: "You are an expert Swift engineer. Produce compileable Swift 6 code. Use Concurrency and Codable where appropriate.",
        config: GenerationConfig(maxTokens: 1200, temperature: 0.3)
    )

    public static let emailDraft = PromptTemplatePack(
        name: "email-draft",
        systemPrompt: "Write polished emails in the requested tone.",
        userPromptTemplate: "Recipient: {{recipient}}\nTone: {{tone}}\nPurpose: {{purpose}}\nKey points:\n{{points}}\n\nDraft the email.",
        config: GenerationConfig(maxTokens: 512, temperature: 0.5),
        tags: ["productivity", "writing"]
    )

    public static let meetingSummary = PromptTemplatePack(
        name: "meeting-summary",
        systemPrompt: "Summarize meeting transcripts into decisions, action items, owners, and due dates.",
        userPromptTemplate: "Transcript:\n{{transcript}}\n\nProvide: 1) decisions, 2) action items with owner+due, 3) open questions.",
        config: GenerationConfig(maxTokens: 700, temperature: 0.3),
        tags: ["productivity"]
    )

    public static let quickQAPolicy = RetrievalPolicyPack(
        name: "quickQA",
        chunker: Chunker(maxCharacters: 600, overlap: 60),
        retrievalLimit: 4,
        vectorWeight: 0.7,
        contextBudgetChars: 2500
    )

    public static let deepResearchPolicy = RetrievalPolicyPack(
        name: "deepResearch",
        chunker: Chunker(maxCharacters: 1200, overlap: 150),
        retrievalLimit: 10,
        vectorWeight: 0.6,
        contextBudgetChars: 10_000
    )
}
