import Foundation
import AIKit
import CoreML
import CoreMLLLM

/// On-device tool-calling backend powered by FunctionGemma-270M (Gemma 3
/// fine-tuned for function calling, runs on ANE).
///
/// This is the **recommended** tool-calling path for LocalAIKit. Unlike the
/// prompt-injection fallback used by `CoreMLLLMBackend`, FunctionGemma
/// emits structured function calls (`<start_function_call>name{json}<end_function_call>`)
/// via its native chat template — no best-effort JSON parsing, much higher
/// tool-selection accuracy on small models.
///
/// ## Caveat
///
/// Requires a one-time ~420 MB download from HuggingFace. If you need a
/// zero-download fallback, use `CoreMLLLMBackend` (which tool-calls via
/// `ToolPromptInjector`).
///
/// ## Usage
///
/// ```swift
/// let modelsDir = URL.documentsDirectory.appending(path: "models")
/// let backend = FunctionGemmaBackend(modelsDir: modelsDir)
/// let result = try await AIKit.askWithTools(
///     "Turn on the flashlight",
///     tools: [flashlightTool],
///     backend: backend
/// )
/// ```
public final class FunctionGemmaBackend: AIBackend, @unchecked Sendable {

    /// Where the FunctionGemma bundle comes from.
    public enum Source: Sendable {
        /// Pre-downloaded bundle directory (contains `model.mlmodelc` or `model.mlpackage`).
        case bundleURL(URL)
        /// Download from the default HuggingFace repo on first `load()` into
        /// `modelsDir/functiongemma-270m/`. Gated repos need `hfToken`.
        case download(modelsDir: URL, hfToken: String?)
    }

    public let info: BackendInfo
    public let source: Source
    public let computeUnits: MLComputeUnits

    private var fg: FunctionGemma?
    private let stateLock = NSLock()
    private let inferenceLock = NSLock()

    public init(
        source: Source,
        computeUnits: MLComputeUnits = .cpuAndNeuralEngine
    ) {
        self.source = source
        self.computeUnits = computeUnits
        self.info = BackendInfo(
            name: "coreml-llm.functiongemma-270m",
            version: "1.0",
            capabilities: [.textGeneration, .streaming, .toolCalling, .chatTemplate, .statefulSession],
            contextLength: 2048,
            preferredDevice: "ANE"
        )
    }

    /// Construct from a pre-downloaded bundle directory.
    public convenience init(
        bundleURL: URL,
        computeUnits: MLComputeUnits = .cpuAndNeuralEngine
    ) {
        self.init(source: .bundleURL(bundleURL), computeUnits: computeUnits)
    }

    /// Construct with lazy download: the bundle fetches from HuggingFace on
    /// first `load()` into `modelsDir/functiongemma-270m/`.
    public convenience init(
        modelsDir: URL,
        hfToken: String? = nil,
        computeUnits: MLComputeUnits = .cpuAndNeuralEngine
    ) {
        self.init(source: .download(modelsDir: modelsDir, hfToken: hfToken), computeUnits: computeUnits)
    }

    public var isLoaded: Bool {
        get async { stateLock.withLock { fg != nil } }
    }

    public func load() async throws {
        try await load(onDownloadProgress: nil)
    }

    /// `load()` with a byte-level progress callback fired during the HuggingFace download.
    /// No-op once the bundle is resident in memory.
    public func load(
        progress: @escaping @Sendable (Gemma3BundleDownloader.Progress) -> Void
    ) async throws {
        try await load(onDownloadProgress: progress)
    }

    private func load(
        onDownloadProgress: (@Sendable (Gemma3BundleDownloader.Progress) -> Void)?
    ) async throws {
        if stateLock.withLock({ fg != nil }) { return }
        do {
            let loaded: FunctionGemma
            switch source {
            case .bundleURL(let url):
                loaded = try await FunctionGemma.load(bundleURL: url, computeUnits: computeUnits)
            case .download(let modelsDir, let token):
                loaded = try await FunctionGemma.downloadAndLoad(
                    modelsDir: modelsDir,
                    hfToken: token,
                    computeUnits: computeUnits,
                    onProgress: onDownloadProgress
                )
            }
            stateLock.withLock { self.fg = loaded }
        } catch {
            throw AIError.modelLoadFailed(error.localizedDescription)
        }
    }

    public func unload() async {
        stateLock.withLock { fg = nil }
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        try await load()
        guard let fg = stateLock.withLock({ self.fg }) else { throw AIError.modelNotLoaded }

        let mappedMessages = Self.mapMessages(messages)
        let mappedTools: [[String: Any]]? = tools.isEmpty ? nil : tools.map { $0.openAIJSON() }
        let maxTokens = config.maxTokens

        let output: String
        let elapsed: TimeInterval
        do {
            (output, elapsed) = try inferenceLock.withLock {
                let start = Date()
                let text = try fg.generate(
                    messages: mappedMessages,
                    tools: mappedTools,
                    maxNewTokens: maxTokens
                )
                return (text, Date().timeIntervalSince(start))
            }
        } catch {
            throw AIError.generationFailed(error.localizedDescription)
        }

        let (cleaned, calls) = Self.parseOutput(output, fg: fg, tools: tools)
        let finish: FinishReason = calls.isEmpty ? .stop : .toolCalls
        return GenerationResult(
            message: .assistant(cleaned, toolCalls: calls),
            usage: GenerationUsage(decodeTimeSeconds: elapsed),
            finishReason: finish
        )
    }

    /// Streaming variant. For tool-calling workloads FunctionGemma's output
    /// must be parsed in full before we know whether it's plain text or a
    /// structured call, so we buffer the whole response and emit a single
    /// text delta + any tool calls at the end. Use this path for feature
    /// parity with the non-streaming `generate` — not for token-by-token UX.
    public func stream(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await self.generate(messages: messages, tools: tools, config: config)
                    if !result.message.content.isEmpty {
                        continuation.yield(GenerationChunk(delta: result.message.content))
                    }
                    for call in result.message.toolCalls {
                        continuation.yield(GenerationChunk(toolCall: call))
                    }
                    continuation.yield(GenerationChunk(finished: true, finishReason: result.finishReason))
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

    // MARK: - Helpers

    private static func mapMessages(_ messages: [Message]) -> [[String: Any]] {
        messages.map { m -> [String: Any] in
            let roleStr: String
            switch m.role {
            case .system: roleStr = "system"
            case .user: roleStr = "user"
            case .assistant: roleStr = "assistant"
            case .tool: roleStr = "tool"
            }
            return ["role": roleStr, "content": m.content]
        }
    }

    /// Extract every `<start_function_call>…<end_function_call>` span from
    /// `output`, parse each as `name{json_args}` (optional `call:` prefix),
    /// and return the user-visible text with those spans stripped out.
    private static func parseOutput(
        _ output: String,
        fg: FunctionGemma,
        tools: [ToolSpec]
    ) -> (text: String, calls: [ToolCall]) {
        guard !tools.isEmpty else {
            return (output.trimmingCharacters(in: .whitespacesAndNewlines), [])
        }
        let startMarker = fg.config.functionCallStart
        let endMarker = fg.config.functionCallEnd
        let allowed = Set(tools.map(\.name))

        var calls: [ToolCall] = []
        var segments: [String] = []
        var cursor = output.startIndex
        while let s = output.range(of: startMarker, range: cursor..<output.endIndex),
              let e = output.range(of: endMarker, range: s.upperBound..<output.endIndex) {
            segments.append(String(output[cursor..<s.lowerBound]))
            let payload = String(output[s.upperBound..<e.lowerBound])
            if let parsed = parseCallPayload(payload), allowed.contains(parsed.name) {
                calls.append(ToolCall(
                    id: "call_\(calls.count)",
                    name: parsed.name,
                    arguments: parsed.arguments
                ))
            }
            cursor = e.upperBound
        }
        segments.append(String(output[cursor..<output.endIndex]))
        let cleaned = segments.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned, calls)
    }

    /// Parse a single `name{json}` or `call:name{json}` payload.
    private static func parseCallPayload(_ payload: String) -> (name: String, arguments: String)? {
        var s = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("call:") { s.removeFirst("call:".count) }
        guard let braceIdx = s.firstIndex(of: "{") else { return nil }
        let name = String(s[..<braceIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        let args = String(s[braceIdx...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !args.isEmpty else { return nil }
        return (name, args)
    }
}
