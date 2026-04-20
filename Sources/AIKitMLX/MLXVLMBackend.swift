import Foundation
import AIKit
import MLX
import MLXVLM
import MLXLMCommon
import Hub

public final class MLXVLMBackend: AIBackend, @unchecked Sendable {
    public let info: BackendInfo
    public let modelId: String
    public let hubRepoId: String
    private var container: ModelContainer?
    private let lock = NSLock()

    public init(modelId: String, hubRepoId: String, contextLength: Int = 4096) {
        self.modelId = modelId
        self.hubRepoId = hubRepoId
        self.info = BackendInfo(
            name: "mlx.vlm.\(modelId)",
            version: "1.0",
            capabilities: [.textGeneration, .streaming, .vision, .chatTemplate, .tokenization],
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
            let factory = VLMModelFactory.shared
            let configuration = ModelConfiguration(id: hubRepoId)
            MLX.GPU.set(cacheLimit: 256 * 1024 * 1024)
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
        var output = ""
        let start = Date()
        for try await chunk in stream(messages: messages, tools: tools, config: config) {
            output += chunk.delta
            if chunk.finished { break }
        }
        let elapsed = Date().timeIntervalSince(start)
        return GenerationResult(
            message: .assistant(output),
            usage: GenerationUsage(decodeTimeSeconds: elapsed),
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
                    let chat = try await Self.mapChat(messages)
                    let input = try UserInput(chat: chat)
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
            let text = messages.map(\.content).joined(separator: "\n")
            return context.tokenizer.encode(text: text).count
        }
    }

    private static func mapChat(_ messages: [Message]) async throws -> [MLXLMCommon.Chat.Message] {
        var result: [MLXLMCommon.Chat.Message] = []
        for m in messages {
            let role: MLXLMCommon.Chat.Message.Role
            switch m.role {
            case .system: role = .system
            case .user: role = .user
            case .assistant: role = .assistant
            case .tool: role = .assistant
            }
            var images: [UserInput.Image] = []
            for att in m.attachments {
                if case .image(let imgAtt) = att {
                    let data = try await imgAtt.loadData()
                    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("aikit-mlx-\(UUID().uuidString).png")
                    try data.write(to: tmp)
                    images.append(.url(tmp))
                }
            }
            result.append(MLXLMCommon.Chat.Message(role: role, content: m.content, images: images, videos: []))
        }
        return result
    }
}
