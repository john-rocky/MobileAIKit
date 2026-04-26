import Foundation
import AIKit
import CoreMLLLM

/// Composition backend that pairs a chat / vision model (typically
/// ``CoreMLLLMBackend`` with `Gemma 4 E2B`) with ``FunctionGemmaBackend`` for
/// tool selection.
///
/// **Why this exists:** small chat models like Gemma 4 E2B answer "I'm just a
/// text-based AI" when asked to call camera / location / calendar tools because
/// their safety alignment overrides prompt-injected tool instructions.
/// FunctionGemma-270M is fine-tuned to emit native function calls and routes
/// these requests reliably. ``CoreMLAgentBackend`` runs both side-by-side and
/// dispatches each generation by whether tools are in scope:
///
/// - `tools.isEmpty`  → ``chatBackend`` (vision, audio, plain chat, summaries)
/// - `tools.nonEmpty` → ``toolBackend`` (function calling)
///
/// `describe_image`, `transcribe`, and similar host tools all internally call
/// `backend.generate(messages:tools:[],config:)`, so they correctly land on
/// the chat backend with the original image / audio attachments preserved.
///
/// ## Usage
///
/// ```swift
/// let agentBackend = CoreMLAgentBackend()  // E2B + FunctionGemma in default dirs
/// let agent = await AgentKit.build(backend: agentBackend)
/// ```
public final class CoreMLAgentBackend: AIBackend, DownloadableBackend, @unchecked Sendable {
    public let chatBackend: CoreMLLLMBackend
    public let toolBackend: FunctionGemmaBackend
    public let info: BackendInfo

    public init(
        chatBackend: CoreMLLLMBackend,
        toolBackend: FunctionGemmaBackend
    ) {
        self.chatBackend = chatBackend
        self.toolBackend = toolBackend
        // Take the chat backend's capabilities (vision/audio/etc) and ensure
        // .toolCalling is advertised — even if the chat model itself is bad at
        // tools, the routing layer can.
        var caps = chatBackend.info.capabilities
        caps.insert(.toolCalling)
        self.info = BackendInfo(
            name: "coreml-agent.\(chatBackend.info.name)+\(toolBackend.info.name)",
            version: "1.0",
            capabilities: caps,
            contextLength: chatBackend.info.contextLength,
            preferredDevice: chatBackend.info.preferredDevice
        )
    }

    /// Convenience: build the recommended pairing (Gemma 4 E2B + FunctionGemma-270M).
    /// FunctionGemma is fetched into `<Documents>/LocalAIKit/models/` on first run.
    public convenience init(
        chatModel: CoreMLLLMBackend.ModelInfo = .gemma4e2b,
        modelsDir: URL? = nil,
        hfToken: String? = nil
    ) {
        let chat = CoreMLLLMBackend(model: chatModel)
        let dir = modelsDir ?? Self.defaultModelsDir()
        let tool = FunctionGemmaBackend(modelsDir: dir, hfToken: hfToken)
        self.init(chatBackend: chat, toolBackend: tool)
    }

    public var isLoaded: Bool {
        get async {
            let chatLoaded = await chatBackend.isLoaded
            let toolLoaded = await toolBackend.isLoaded
            return chatLoaded && toolLoaded
        }
    }

    public func load() async throws {
        try await chatBackend.load()
        try await toolBackend.load()
    }

    public func unload() async {
        await chatBackend.unload()
        await toolBackend.unload()
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        let target: any AIBackend = tools.isEmpty ? chatBackend : toolBackend
        return try await target.generate(messages: messages, tools: tools, config: config)
    }

    public func stream(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        let target: any AIBackend = tools.isEmpty ? chatBackend : toolBackend
        return target.stream(messages: messages, tools: tools, config: config)
    }

    public func tokenCount(for messages: [Message]) async throws -> Int {
        try await chatBackend.tokenCount(for: messages)
    }

    // MARK: - DownloadableBackend

    public var displayModelName: String {
        "\(chatBackend.displayModelName) + FunctionGemma"
    }

    public var displayModelSize: String? {
        // FunctionGemma is ~420 MB; chat backend's size string varies. Show
        // both so the user knows what they're committing to.
        if let chatSize = chatBackend.displayModelSize {
            return "\(chatSize) + ~420 MB"
        }
        return "+ ~420 MB tool model"
    }

    public func bootstrap(
        progress: @Sendable @escaping (ModelLoadPhase) -> Void
    ) async throws {
        // Phase weighting: the chat model is the dominant download (gemma4e2b
        // is ~3.1 GB vs FunctionGemma ~420 MB), so allocate ~88% of the
        // progress bar to the chat phase and the remaining ~12% to the tool
        // phase. Warm-up phases share the bar's status text.
        let chatWeight = 0.88

        // Phase 1: chat backend download.
        if !chatBackend.isDownloaded {
            progress(.downloading(fraction: 0, status: "Preparing chat model…"))
            try await chatBackend.download { fraction, status in
                let scaled = fraction * chatWeight
                let text = status.isEmpty ? "Downloading chat model…" : "Chat model: \(status)"
                progress(.downloading(fraction: scaled, status: text))
            }
        }

        // Phase 2: chat backend warm-up.
        progress(.warmingUp(status: "Warming up Gemma on the ANE…"))
        try await chatBackend.load { status in
            let text = status.isEmpty ? "Warming up Gemma…" : "Gemma: \(status)"
            progress(.warmingUp(status: text))
        }

        // Phase 3: FunctionGemma download + load. FunctionGemmaBackend's load
        // does both, so the progress callback fires for the download portion
        // and the load itself completes quickly afterwards.
        if !(await toolBackend.isLoaded) {
            progress(.downloading(
                fraction: chatWeight,
                status: "Downloading FunctionGemma-270M…"
            ))
            try await toolBackend.load { p in
                let toolFraction: Double
                if p.bytesTotal > 0 {
                    toolFraction = Double(p.bytesReceived) / Double(p.bytesTotal)
                } else {
                    toolFraction = 0
                }
                let total = chatWeight + toolFraction * (1 - chatWeight)
                let text = "FunctionGemma: \(p.currentFile)"
                progress(.downloading(fraction: total, status: text))
            }
            progress(.warmingUp(status: "Warming up FunctionGemma…"))
        }
    }

    // MARK: - Internals

    private static func defaultModelsDir() -> URL {
        let dir = URL.documentsDirectory
            .appending(path: "LocalAIKit", directoryHint: .isDirectory)
            .appending(path: "models", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
