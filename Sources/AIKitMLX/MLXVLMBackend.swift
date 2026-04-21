import Foundation
import AIKit
import MLX
import MLXVLM
import MLXLMCommon
import Hub

public final class MLXVLMBackend: AIBackend, @unchecked Sendable {
    /// Curated, version-pinned VLM catalog so callers don't re-type HF repo IDs.
    ///
    /// Use as `MLXVLMBackend(model: .qwen25_vl_3b_4bit)` instead of guessing the hub ID.
    public struct Model: Sendable, Hashable {
        public let id: String
        public let hubRepoId: String
        public let displayName: String
        public let contextLength: Int
        public let approximateSizeGB: Double

        public init(
            id: String,
            hubRepoId: String,
            displayName: String,
            contextLength: Int = 4096,
            approximateSizeGB: Double
        ) {
            self.id = id
            self.hubRepoId = hubRepoId
            self.displayName = displayName
            self.contextLength = contextLength
            self.approximateSizeGB = approximateSizeGB
        }

        public static let qwen25_vl_3b_4bit = Model(
            id: "qwen2.5-vl-3b-4bit",
            hubRepoId: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
            displayName: "Qwen2.5-VL 3B (4-bit)",
            contextLength: 32_768,
            approximateSizeGB: 2.0
        )

        public static let qwen25_vl_7b_4bit = Model(
            id: "qwen2.5-vl-7b-4bit",
            hubRepoId: "mlx-community/Qwen2.5-VL-7B-Instruct-4bit",
            displayName: "Qwen2.5-VL 7B (4-bit)",
            contextLength: 32_768,
            approximateSizeGB: 4.2
        )

        public static let smolvlm_256m_instruct_4bit = Model(
            id: "smolvlm-256m-instruct-4bit",
            hubRepoId: "mlx-community/SmolVLM-256M-Instruct-4bit",
            displayName: "SmolVLM 256M Instruct (4-bit)",
            contextLength: 8_192,
            approximateSizeGB: 0.2
        )

        public static let smolvlm_500m_instruct_4bit = Model(
            id: "smolvlm-500m-instruct-4bit",
            hubRepoId: "mlx-community/SmolVLM-500M-Instruct-4bit",
            displayName: "SmolVLM 500M Instruct (4-bit)",
            contextLength: 8_192,
            approximateSizeGB: 0.35
        )

        public static let catalog: [Model] = [
            .smolvlm_256m_instruct_4bit,
            .smolvlm_500m_instruct_4bit,
            .qwen25_vl_3b_4bit,
            .qwen25_vl_7b_4bit
        ]
    }

    public let info: BackendInfo
    public let modelId: String
    public let hubRepoId: String
    /// MLX GPU weight-cache limit in bytes. Set lower on 6 GB iPhones, higher on Pro Max.
    /// Defaults to 256 MB; can also be driven from ``ResourceGovernor`` at the call site.
    public var gpuCacheLimitBytes: Int
    private var container: ModelContainer?
    private let lock = NSLock()

    public init(
        modelId: String,
        hubRepoId: String,
        contextLength: Int = 4096,
        gpuCacheLimitBytes: Int = 256 * 1024 * 1024
    ) {
        self.modelId = modelId
        self.hubRepoId = hubRepoId
        self.gpuCacheLimitBytes = gpuCacheLimitBytes
        self.info = BackendInfo(
            name: "mlx.vlm.\(modelId)",
            version: "1.0",
            capabilities: [.textGeneration, .streaming, .vision, .chatTemplate, .tokenization],
            contextLength: contextLength,
            preferredDevice: "GPU"
        )
    }

    /// Catalog convenience: `MLXVLMBackend(model: .qwen25_vl_3b_4bit)`.
    public convenience init(model: Model, gpuCacheLimitBytes: Int = 256 * 1024 * 1024) {
        self.init(
            modelId: model.id,
            hubRepoId: model.hubRepoId,
            contextLength: model.contextLength,
            gpuCacheLimitBytes: gpuCacheLimitBytes
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
            MLX.GPU.set(cacheLimit: gpuCacheLimitBytes)
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

    /// `load()` with a raw fraction callback.
    ///
    /// The `Double` forwarded here is whatever `Foundation.Progress.fractionCompleted` the MLX
    /// `VLMModelFactory` publishes — in practice this covers the **HuggingFace weight download
    /// phase** only. After the download finishes the factory flips straight to model
    /// initialization without further progress updates, so UIs will see the bar jump from
    /// ~0.99 to 1.0 and the model will still be warming up for ~10 s.
    ///
    /// If you need distinct `.downloading` / `.initializing` / `.ready` stages, prefer
    /// ``load(phase:)`` which exposes a typed ``LoadEvent`` sequence.
    public func load(progress: @escaping @Sendable (Double) -> Void) async throws {
        lock.lock(); let existing = container; lock.unlock()
        if existing != nil { progress(1.0); return }
        do {
            let factory = VLMModelFactory.shared
            let configuration = ModelConfiguration(id: hubRepoId)
            MLX.GPU.set(cacheLimit: gpuCacheLimitBytes)
            let loaded = try await factory.loadContainer(
                hub: HubApi(),
                configuration: configuration
            ) { p in
                progress(p.fractionCompleted)
            }
            lock.lock()
            self.container = loaded
            lock.unlock()
        } catch {
            throw AIError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Distinct lifecycle stages emitted by ``load(phase:)``.
    public enum LoadEvent: Sendable, Hashable {
        /// HuggingFace weight fetch in progress. `fraction` is `0.0…1.0`.
        case downloading(fraction: Double)
        /// Weights are on disk; the MLX factory is warming up the GPU context / KV caches.
        case initializing
        /// Container is resident in memory and ready to ``generate(messages:tools:config:)``.
        case ready
    }

    /// `load()` with typed phase events so UIs can show "Downloading" vs "Warming up"
    /// separately instead of a single opaque bar.
    public func load(phase: @escaping @Sendable (LoadEvent) -> Void) async throws {
        lock.lock(); let existing = container; lock.unlock()
        if existing != nil { phase(.ready); return }
        do {
            let factory = VLMModelFactory.shared
            let configuration = ModelConfiguration(id: hubRepoId)
            MLX.GPU.set(cacheLimit: gpuCacheLimitBytes)
            var sawDownload = false
            let loaded = try await factory.loadContainer(
                hub: HubApi(),
                configuration: configuration
            ) { p in
                sawDownload = true
                phase(.downloading(fraction: p.fractionCompleted))
            }
            if sawDownload { phase(.initializing) }
            lock.lock()
            self.container = loaded
            lock.unlock()
            phase(.ready)
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
