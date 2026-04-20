import Foundation

public struct GenerationConfig: Sendable, Hashable, Codable {
    public var maxTokens: Int
    public var temperature: Float
    public var topP: Float
    public var topK: Int
    public var repetitionPenalty: Float
    public var seed: UInt64?
    public var stopSequences: [String]
    public var stream: Bool
    public var timeout: TimeInterval?

    public init(
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.95,
        topK: Int = 40,
        repetitionPenalty: Float = 1.1,
        seed: UInt64? = nil,
        stopSequences: [String] = [],
        stream: Bool = true,
        timeout: TimeInterval? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.repetitionPenalty = repetitionPenalty
        self.seed = seed
        self.stopSequences = stopSequences
        self.stream = stream
        self.timeout = timeout
    }

    public static let `default` = GenerationConfig()

    public static let deterministic = GenerationConfig(
        temperature: 0.0,
        topP: 1.0,
        topK: 1,
        repetitionPenalty: 1.0
    )

    public static let creative = GenerationConfig(
        temperature: 1.0,
        topP: 0.95,
        topK: 80
    )
}

public struct GenerationUsage: Sendable, Hashable, Codable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int { promptTokens + completionTokens }
    public var prefillTimeSeconds: Double
    public var decodeTimeSeconds: Double
    public var tokensPerSecond: Double {
        decodeTimeSeconds > 0 ? Double(completionTokens) / decodeTimeSeconds : 0
    }

    public init(
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        prefillTimeSeconds: Double = 0,
        decodeTimeSeconds: Double = 0
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.prefillTimeSeconds = prefillTimeSeconds
        self.decodeTimeSeconds = decodeTimeSeconds
    }
}
