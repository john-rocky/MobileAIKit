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

    /// Cap on how many tool specs are forwarded to FunctionGemma per turn.
    /// FunctionGemma-270M's context window is 2048 tokens and each tool spec
    /// serializes to a few hundred — pushing 20+ specs through reliably blows
    /// the prefill budget. The first `maxToolsForRouter` specs are forwarded;
    /// the rest are dropped for the FunctionGemma call (the chat-backend
    /// fallback still sees zero tools, so this only affects routing accuracy).
    public var maxToolsForRouter: Int = 12

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
        if tools.isEmpty {
            log("→ chat (no tools)")
            return try await chatBackend.generate(messages: messages, tools: [], config: config)
        }
        let routerTools = Array(tools.prefix(maxToolsForRouter))
        if routerTools.count < tools.count {
            log("→ tool router (\(routerTools.count) of \(tools.count) tools, capped to fit FunctionGemma context)")
        } else {
            log("→ tool router (\(routerTools.count) tools)")
        }
        do {
            let result = try await toolBackend.generate(messages: messages, tools: routerTools, config: config)
            if isUsable(result.message) {
                log("← tool router produced \(result.message.toolCalls.count) call(s), \(result.message.content.count) chars")
                return result
            }
            // FunctionGemma produced nothing actionable (empty text + no parsed
            // tool call — small 270M model overwhelmed by many tool specs or
            // hallucinated a name not in the registry). Fall back to chat.
            log("← tool router empty, falling back to chat backend")
        } catch {
            // FunctionGemma can throw on context overflow (its window is 2048
            // tokens, easily blown when a host registers 20+ tools). Surface
            // the error for debugging, then fall back so the user gets a reply.
            log("← tool router threw \(error.localizedDescription), falling back to chat backend")
        }
        // Fallback uses tools=[] so the chat backend doesn't try to emit a
        // tool call itself (E2B is bad at it; the whole reason we route via
        // FunctionGemma). At least the user gets a chat response.
        return try await chatBackend.generate(messages: messages, tools: [], config: config)
    }

    public func stream(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        if tools.isEmpty {
            log("→ chat stream (no tools)")
            return chatBackend.stream(messages: messages, tools: [], config: config)
        }
        let routerTools = Array(tools.prefix(maxToolsForRouter))
        if routerTools.count < tools.count {
            log("→ tool router stream (\(routerTools.count) of \(tools.count) tools, capped)")
        } else {
            log("→ tool router stream (\(routerTools.count) tools)")
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                var routedToFallback = false
                do {
                    let result = try await self.toolBackend.generate(
                        messages: messages, tools: routerTools, config: config
                    )
                    if self.isUsable(result.message) {
                        self.log("← tool router stream produced \(result.message.toolCalls.count) call(s), \(result.message.content.count) chars")
                        if !result.message.content.isEmpty {
                            continuation.yield(GenerationChunk(delta: result.message.content))
                        }
                        for call in result.message.toolCalls {
                            continuation.yield(GenerationChunk(toolCall: call))
                        }
                        continuation.yield(GenerationChunk(finished: true, finishReason: result.finishReason))
                        continuation.finish()
                        return
                    }
                    self.log("← tool router stream empty, falling back to chat backend")
                    routedToFallback = true
                } catch {
                    self.log("← tool router stream threw \(error.localizedDescription), falling back to chat backend")
                    routedToFallback = true
                }
                guard routedToFallback else { return }
                do {
                    // tools=[] so chat backend just chats; no double-attempt
                    // at tool emission via prompt injection.
                    let fallback = self.chatBackend.stream(
                        messages: messages, tools: [], config: config
                    )
                    for try await chunk in fallback {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func isUsable(_ message: Message) -> Bool {
        if !message.toolCalls.isEmpty { return true }
        return !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[CoreMLAgentBackend] \(message)")
        #endif
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
