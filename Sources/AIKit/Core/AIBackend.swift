import Foundation

public struct BackendCapabilities: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let textGeneration       = BackendCapabilities(rawValue: 1 << 0)
    public static let streaming            = BackendCapabilities(rawValue: 1 << 1)
    public static let chatTemplate         = BackendCapabilities(rawValue: 1 << 2)
    public static let toolCalling          = BackendCapabilities(rawValue: 1 << 3)
    public static let structuredOutput     = BackendCapabilities(rawValue: 1 << 4)
    public static let constrainedDecoding  = BackendCapabilities(rawValue: 1 << 5)
    public static let vision               = BackendCapabilities(rawValue: 1 << 6)
    public static let audioInput           = BackendCapabilities(rawValue: 1 << 7)
    public static let audioOutput          = BackendCapabilities(rawValue: 1 << 8)
    public static let embeddings           = BackendCapabilities(rawValue: 1 << 9)
    public static let statefulSession      = BackendCapabilities(rawValue: 1 << 10)
    public static let reasoning            = BackendCapabilities(rawValue: 1 << 11)
    public static let tokenization         = BackendCapabilities(rawValue: 1 << 12)
    public static let logitsAccess         = BackendCapabilities(rawValue: 1 << 13)
}

public struct BackendInfo: Sendable, Hashable {
    public let name: String
    public let version: String
    public let capabilities: BackendCapabilities
    public let contextLength: Int
    public let preferredDevice: String

    public init(
        name: String,
        version: String,
        capabilities: BackendCapabilities,
        contextLength: Int,
        preferredDevice: String
    ) {
        self.name = name
        self.version = version
        self.capabilities = capabilities
        self.contextLength = contextLength
        self.preferredDevice = preferredDevice
    }
}

public struct GenerationChunk: Sendable, Hashable {
    public let delta: String
    public let toolCall: ToolCall?
    public let finished: Bool
    public let finishReason: FinishReason?

    public init(
        delta: String = "",
        toolCall: ToolCall? = nil,
        finished: Bool = false,
        finishReason: FinishReason? = nil
    ) {
        self.delta = delta
        self.toolCall = toolCall
        self.finished = finished
        self.finishReason = finishReason
    }
}

public enum FinishReason: String, Sendable, Hashable, Codable {
    case stop
    case length
    case toolCalls
    case cancelled
    case error
}

public struct GenerationResult: Sendable, Hashable {
    public let message: Message
    public let usage: GenerationUsage
    public let finishReason: FinishReason

    public init(message: Message, usage: GenerationUsage, finishReason: FinishReason) {
        self.message = message
        self.usage = usage
        self.finishReason = finishReason
    }
}

public protocol AIBackend: Sendable, AnyObject {
    var info: BackendInfo { get }
    var isLoaded: Bool { get async }

    func load() async throws
    func unload() async

    func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult

    func stream(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error>

    func tokenCount(for messages: [Message]) async throws -> Int

    func embed(_ text: String) async throws -> [Float]
}

public extension AIBackend {
    func embed(_ text: String) async throws -> [Float] {
        throw AIError.unsupportedCapability("embeddings")
    }
}
