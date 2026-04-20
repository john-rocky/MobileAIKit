import Foundation

/// Runtime-declared capabilities of a backend.
///
/// Query with `backend.info.capabilities.contains(.vision)` before sending
/// image attachments, for example.
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

/// Descriptive, runtime-queryable metadata for a backend instance.
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

/// Incremental unit emitted by ``AIBackend/stream(messages:tools:config:)``.
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

/// Why a generation ended.
public enum FinishReason: String, Sendable, Hashable, Codable {
    case stop
    case length
    case toolCalls
    case cancelled
    case error
}

/// Full result returned by ``AIBackend/generate(messages:tools:config:)``.
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

/// Unified protocol for any local AI runtime.
///
/// Every concrete backend (CoreML-LLM, MLX, llama.cpp, Foundation Models,
/// generic CoreML, a router) conforms to this. Call ``load()`` once before
/// your first generation for best latency; it's also called lazily on demand.
///
/// Backends are **reference types and `Sendable`**. They may be shared across
/// actors. Use a `BackendRouter` to fall back between multiple backends.
public protocol AIBackend: Sendable, AnyObject {
    /// Descriptive metadata including capabilities and context length.
    var info: BackendInfo { get }

    /// Whether model weights are resident in memory.
    var isLoaded: Bool { get async }

    /// Eagerly loads weights and warms up caches.
    func load() async throws

    /// Frees model weights, clears caches.
    func unload() async

    /// Produces a complete assistant message. Blocks until generation is done.
    func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult

    /// Streams ``GenerationChunk`` deltas as tokens are produced.
    func stream(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error>

    /// Token count for the given messages using the backend's own tokenizer.
    func tokenCount(for messages: [Message]) async throws -> Int

    /// Returns an embedding vector. Default throws ``AIError/unsupportedCapability(_:)``.
    func embed(_ text: String) async throws -> [Float]
}

public extension AIBackend {
    func embed(_ text: String) async throws -> [Float] {
        throw AIError.unsupportedCapability("embeddings")
    }
}
