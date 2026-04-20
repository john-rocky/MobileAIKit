import Foundation
import AIKit
import MLX
import MLXLLM
import MLXLMCommon
import Hub

public final class MLXBackend: AIBackend, @unchecked Sendable {
    public let info: BackendInfo
    public let modelId: String
    public let hubRepoId: String
    public let template: ChatTemplate
    private var container: ModelContainer?
    private let lock = NSLock()

    public init(
        modelId: String,
        hubRepoId: String,
        template: ChatTemplate? = nil,
        contextLength: Int = 4096
    ) {
        self.modelId = modelId
        self.hubRepoId = hubRepoId
        self.template = template ?? ChatTemplate.auto(name: modelId)
        self.info = BackendInfo(
            name: "mlx.\(modelId)",
            version: "1.0",
            capabilities: [.textGeneration, .streaming, .chatTemplate, .tokenization, .logitsAccess, .statefulSession],
            contextLength: contextLength,
            preferredDevice: "GPU"
        )
    }

    public var isLoaded: Bool {
        get async { container != nil }
    }

    public func load() async throws {
        lock.lock(); let existing = container; lock.unlock()
        if existing != nil { return }
        do {
            let factory = LLMModelFactory.shared
            let configuration = ModelConfiguration(id: hubRepoId)
            MLX.GPU.set(cacheLimit: 128 * 1024 * 1024)
            let loaded = try await factory.loadContainer(
                hub: HubApi(),
                configuration: configuration
            ) { _ in }
            lock.lock()
            self.container = loaded
            lock.unlock()
        } catch {
            throw AIError.modelLoadFailed(error.localizedDescription)
        }
    }

    public func unload() async {
        lock.lock(); container = nil; lock.unlock()
        MLX.GPU.clearCache()
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        var accumulated = ""
        var completionTokens = 0
        var tokensPerSecond: Double = 0
        let start = Date()
        for try await chunk in stream(messages: messages, tools: tools, config: config) {
            accumulated += chunk.delta
            if chunk.finished { break }
        }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0 {
            let tokenEstimate = accumulated.split(separator: " ").count
            tokensPerSecond = Double(tokenEstimate) / elapsed
            completionTokens = tokenEstimate
        }
        let usage = GenerationUsage(
            promptTokens: 0,
            completionTokens: completionTokens,
            decodeTimeSeconds: elapsed
        )
        _ = tokensPerSecond
        return GenerationResult(
            message: .assistant(accumulated),
            usage: usage,
            finishReason: .stop
        )
    }

    public func stream(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.load()
                    guard let container = self.container else { throw AIError.modelNotLoaded }
                    let input = try UserInput(chat: Self.mapChat(messages))
                    var params = GenerateParameters()
                    params.maxTokens = config.maxTokens
                    params.temperature = config.temperature
                    params.topP = config.topP
                    params.repetitionPenalty = config.repetitionPenalty
                    try await container.perform { context in
                        let prepared = try await context.processor.prepare(input: input)
                        let generation = try MLXLMCommon.generate(
                            input: prepared,
                            parameters: params,
                            context: context
                        )
                        for await event in generation {
                            if Task.isCancelled { break }
                            switch event {
                            case .chunk(let text):
                                continuation.yield(GenerationChunk(delta: text))
                            case .info:
                                break
                            @unknown default:
                                break
                            }
                        }
                    }
                    continuation.yield(GenerationChunk(finished: true, finishReason: .stop))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func tokenCount(for messages: [Message]) async throws -> Int {
        try await load()
        guard let container = container else { throw AIError.modelNotLoaded }
        return try await container.perform { context in
            let text = messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
            return context.tokenizer.encode(text: text).count
        }
    }

    private static func mapChat(_ messages: [Message]) -> [MLXLMCommon.Chat.Message] {
        messages.map { m in
            let role: MLXLMCommon.Chat.Message.Role
            switch m.role {
            case .system: role = .system
            case .user: role = .user
            case .assistant: role = .assistant
            case .tool: role = .assistant
            }
            return MLXLMCommon.Chat.Message(role: role, content: m.content, images: [], videos: [])
        }
    }
}
