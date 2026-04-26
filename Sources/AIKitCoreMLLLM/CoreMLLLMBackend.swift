import Foundation
import AIKit
import CoreML
@_exported import CoreMLLLM
import CoreGraphics
import ImageIO

public final class CoreMLLLMBackend: AIBackend, DownloadableBackend, @unchecked Sendable {
    public enum Source: Sendable {
        case directory(URL)
        case model(ModelDownloader.ModelInfo)
    }

    public let info: BackendInfo
    public let source: Source
    public let computeUnits: MLComputeUnits
    public var progressHandler: (@Sendable (String) -> Void)?

    /// Controls how PDF / text / generic file attachments are inlined into the
    /// user prompt. Gemma 4 natively ingests only images + audio, so anything
    /// else is rendered to text and appended to `message.content` before being
    /// sent to the model. Tune the char budgets here.
    public var attachmentIngestionOptions: AttachmentIngestionOptions = .default

    private var llm: CoreMLLLM?
    private let lock = NSLock()

    public init(
        source: Source,
        computeUnits: MLComputeUnits = .cpuAndNeuralEngine,
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) {
        self.source = source
        self.computeUnits = computeUnits
        self.progressHandler = progressHandler
        let name: String
        switch source {
        case .directory(let url): name = "coreml-llm.\(url.lastPathComponent)"
        case .model: name = "coreml-llm.hosted"
        }
        self.info = BackendInfo(
            name: name,
            version: "1.0",
            capabilities: [.textGeneration, .streaming, .vision, .audioInput, .chatTemplate, .statefulSession, .toolCalling, .structuredOutput],
            contextLength: 8192,
            preferredDevice: "ANE"
        )
    }

    public convenience init(directory: URL, computeUnits: MLComputeUnits = .cpuAndNeuralEngine) {
        self.init(source: .directory(directory), computeUnits: computeUnits)
    }

    public convenience init(model: ModelDownloader.ModelInfo, computeUnits: MLComputeUnits = .cpuAndNeuralEngine) {
        self.init(source: .model(model), computeUnits: computeUnits)
    }

    /// Re-exported so callers can write `CoreMLLLMBackend.ModelInfo.gemma4e2b` without importing `CoreMLLLM` directly.
    public typealias ModelInfo = ModelDownloader.ModelInfo

    /// Models bundled with `coreml-llm`. Use this to populate pickers
    /// without reaching into the underlying download type.
    public static var availableModels: [ModelInfo] {
        ModelDownloader.ModelInfo.defaults
    }

    public var isLoaded: Bool {
        get async { llm != nil }
    }

    public func load() async throws {
        if lock.withLock({ llm }) != nil { return }
        do {
            let loaded: CoreMLLLM
            switch source {
            case .directory(let url):
                loaded = try await CoreMLLLM.load(from: url, computeUnits: computeUnits, onProgress: progressHandler)
            case .model(let info):
                loaded = try await CoreMLLLM.load(model: info, computeUnits: computeUnits, onProgress: progressHandler)
            }
            lock.withLock { self.llm = loaded }
        } catch {
            throw AIError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// `load()` variant that attaches a one-shot progress handler (status strings) without
    /// clobbering the long-lived `progressHandler` property.
    public func load(progress: @escaping @Sendable (String) -> Void) async throws {
        let previous = progressHandler
        progressHandler = progress
        defer { progressHandler = previous }
        try await load()
    }

    /// Download the model weights without loading them into memory.
    ///
    /// Useful when the app wants to pre-download on Wi-Fi (e.g. during onboarding) and
    /// defer the 10–30 s ANE warm-up of ``load()`` until the user actually needs the model.
    /// No-op when the backend was constructed from a local directory.
    ///
    /// - Parameter progress: Optional closure called with `(fraction, statusText)` while the
    ///   download runs. `fraction` is `0.0…1.0`.
    public func download(
        progress: (@Sendable (Double, String) -> Void)? = nil
    ) async throws {
        guard case .model(let info) = source else { return }
        let downloader = ModelDownloader.shared
        if downloader.isDownloaded(info) { return }

        let pollTask: Task<Void, Never>?
        if let progress {
            pollTask = Task { @MainActor in
                while !Task.isCancelled {
                    progress(downloader.progress, downloader.status)
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if downloader.isDownloaded(info) { break }
                }
            }
        } else {
            pollTask = nil
        }
        defer { pollTask?.cancel() }

        do {
            _ = try await downloader.download(info)
        } catch {
            throw AIError.downloadFailed(error.localizedDescription)
        }
    }

    /// Whether the model's weights are present on disk (no network or memory check).
    public var isDownloaded: Bool {
        switch source {
        case .directory(let url): return FileManager.default.fileExists(atPath: url.path)
        case .model(let info): return ModelDownloader.shared.isDownloaded(info)
        }
    }

    // MARK: - DownloadableBackend

    public var displayModelName: String {
        switch source {
        case .directory(let url): return url.lastPathComponent
        case .model(let info): return info.name
        }
    }

    public var displayModelSize: String? {
        switch source {
        case .directory: return nil
        case .model(let info): return info.size
        }
    }

    public func bootstrap(
        progress: @Sendable @escaping (ModelLoadPhase) -> Void
    ) async throws {
        if !isDownloaded {
            progress(.downloading(fraction: 0, status: "Preparing…"))
            try await download { fraction, status in
                progress(.downloading(
                    fraction: fraction,
                    status: status.isEmpty ? "Downloading…" : status
                ))
            }
        }
        progress(.warmingUp(status: "Warming up the ANE…"))
        try await load { status in
            progress(.warmingUp(
                status: status.isEmpty ? "Warming up the ANE…" : status
            ))
        }
    }

    public func unload() async {
        lock.withLock { llm = nil }
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        try await load()
        guard let llm = llm else { throw AIError.modelNotLoaded }
        let withAttachments = AttachmentIngestion.expand(messages: messages, options: attachmentIngestionOptions)
        let augmented = ToolPromptInjector.inject(tools: tools, into: withAttachments)
        let (mapped, image, audio) = try await Self.prepare(augmented)
        let start = Date()
        let output = try await llm.generate(
            mapped,
            image: image,
            audio: audio,
            maxTokens: config.maxTokens
        )
        let elapsed = Date().timeIntervalSince(start)
        let (cleanedText, parsedCalls) = ToolPromptInjector.parse(output: output, tools: tools)
        let finish: FinishReason = parsedCalls.isEmpty ? .stop : .toolCalls
        return GenerationResult(
            message: .assistant(cleanedText, toolCalls: parsedCalls),
            usage: GenerationUsage(decodeTimeSeconds: elapsed),
            finishReason: finish
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
                    guard let llm = self.llm else { throw AIError.modelNotLoaded }
                    let withAttachments = AttachmentIngestion.expand(messages: messages, options: self.attachmentIngestionOptions)
                    let augmented = ToolPromptInjector.inject(tools: tools, into: withAttachments)
                    let (mapped, image, audio) = try await Self.prepare(augmented)
                    let video = Self.firstVideoURL(in: augmented)
                    let stream: AsyncStream<String>
                    if let video {
                        stream = try await llm.stream(
                            mapped,
                            videoURL: video,
                            maxTokens: config.maxTokens
                        )
                    } else {
                        stream = try await llm.stream(
                            mapped,
                            image: image,
                            audio: audio,
                            maxTokens: config.maxTokens
                        )
                    }
                    var buffered = ""
                    let hasTools = !tools.isEmpty
                    for await piece in stream {
                        if Task.isCancelled { break }
                        if hasTools {
                            // Hold output back so we don't leak a tool-call JSON
                            // prefix (e.g. `{"tool_calls":`) to the caller as chat text.
                            buffered += piece
                        } else {
                            continuation.yield(GenerationChunk(delta: piece))
                        }
                    }
                    if hasTools {
                        let (cleanedText, parsedCalls) = ToolPromptInjector.parse(output: buffered, tools: tools)
                        if !cleanedText.isEmpty {
                            continuation.yield(GenerationChunk(delta: cleanedText))
                        }
                        for call in parsedCalls {
                            continuation.yield(GenerationChunk(toolCall: call))
                        }
                        continuation.yield(GenerationChunk(finished: true, finishReason: parsedCalls.isEmpty ? .stop : .toolCalls))
                    } else {
                        continuation.yield(GenerationChunk(finished: true, finishReason: .stop))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func tokenCount(for messages: [Message]) async throws -> Int {
        let joined = messages.map(\.content).joined(separator: "\n")
        return joined.count / 4
    }

    private static func prepare(_ messages: [Message]) async throws -> ([CoreMLLLM.Message], CGImage?, [Float]?) {
        var mapped: [CoreMLLLM.Message] = []
        var image: CGImage?
        var audio: [Float]?
        for m in messages {
            let role: CoreMLLLM.Message.Role
            switch m.role {
            case .system: role = .system
            case .user: role = .user
            case .assistant: role = .assistant
            case .tool: role = .assistant
            }
            mapped.append(.init(role: role, content: m.content))
            for att in m.attachments {
                switch att {
                case .image(let img):
                    if image == nil {
                        let data = try await img.loadData()
                        image = try Self.cgImage(from: data)
                    }
                case .audio(let audioAtt):
                    if audio == nil {
                        let data = try audioAtt.loadData()
                        audio = Self.pcmFloats(from: data)
                    }
                case .video:
                    // Routed through `llm.stream(videoURL:)` in `stream`, not prepared here.
                    break
                case .pdf, .text, .file:
                    // Already extracted to text by AttachmentIngestion.expand and
                    // stripped from message.attachments before prepare runs — any
                    // residual case here would be a programmer error upstream.
                    break
                }
            }
        }
        return (mapped, image, audio)
    }

    private static func firstVideoURL(in messages: [Message]) -> URL? {
        for m in messages {
            for att in m.attachments {
                if case .video(let v) = att { return v.fileURL }
            }
        }
        return nil
    }

    private static func cgImage(from data: Data) throws -> CGImage {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw AIError.invalidAttachment("Unable to decode image")
        }
        return cg
    }

    private static func pcmFloats(from data: Data) -> [Float] {
        data.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: Float.self)
            return Array(buffer)
        }
    }
}
