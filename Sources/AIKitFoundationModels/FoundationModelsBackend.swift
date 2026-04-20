import Foundation
import AIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
public final class FoundationModelsBackend: AIBackend, @unchecked Sendable {
    public let info: BackendInfo
    private let instructionsText: String?
    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif
    private let lock = NSLock()

    public init(instructions: String? = nil) {
        self.instructionsText = instructions
        self.info = BackendInfo(
            name: "apple.foundation-models",
            version: "1.0",
            capabilities: [.textGeneration, .streaming, .chatTemplate, .toolCalling, .structuredOutput, .statefulSession],
            contextLength: 8192,
            preferredDevice: "Neural Engine"
        )
    }

    public var isLoaded: Bool {
        get async {
            #if canImport(FoundationModels)
            let availability = SystemLanguageModel.default.availability
            if case .available = availability { return true }
            return false
            #else
            return false
            #endif
        }
    }

    public func load() async throws {
        #if canImport(FoundationModels)
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            let instructions = instructionsText.map { Instructions($0) }
            let newSession: LanguageModelSession
            if let instructions {
                newSession = LanguageModelSession(instructions: instructions)
            } else {
                newSession = LanguageModelSession()
            }
            lock.lock(); session = newSession; lock.unlock()
        case .unavailable(let reason):
            throw AIError.modelLoadFailed("Foundation Models unavailable: \(reason)")
        @unknown default:
            throw AIError.modelLoadFailed("Foundation Models availability unknown")
        }
        #else
        throw AIError.unsupportedBackend("FoundationModels framework not available in this SDK")
        #endif
    }

    public func unload() async {
        #if canImport(FoundationModels)
        lock.lock(); session = nil; lock.unlock()
        #endif
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        #if canImport(FoundationModels)
        let session = try await ensureSession()
        let prompt = Prompt(Self.buildPrompt(from: messages))
        let options = GenerationOptions(
            temperature: Double(config.temperature),
            maximumResponseTokens: config.maxTokens
        )
        let start = Date()
        let response = try await session.respond(to: prompt, options: options)
        let elapsed = Date().timeIntervalSince(start)
        let usage = GenerationUsage(decodeTimeSeconds: elapsed)
        return GenerationResult(
            message: .assistant(response.content),
            usage: usage,
            finishReason: .stop
        )
        #else
        throw AIError.unsupportedBackend("FoundationModels framework not available in this SDK")
        #endif
    }

    public func stream(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    #if canImport(FoundationModels)
                    let session = try await self.ensureSession()
                    let prompt = Prompt(Self.buildPrompt(from: messages))
                    let options = GenerationOptions(
                        temperature: Double(config.temperature),
                        maximumResponseTokens: config.maxTokens
                    )
                    let stream = session.streamResponse(to: prompt, options: options)
                    var lastLength = 0
                    for try await partial in stream {
                        let text = Self.extractText(from: partial)
                        if text.count > lastLength {
                            let delta = String(text.suffix(text.count - lastLength))
                            lastLength = text.count
                            continuation.yield(GenerationChunk(delta: delta))
                        }
                    }
                    continuation.yield(GenerationChunk(finished: true, finishReason: .stop))
                    continuation.finish()
                    #else
                    throw AIError.unsupportedBackend("FoundationModels framework not available in this SDK")
                    #endif
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func tokenCount(for messages: [Message]) async throws -> Int {
        Self.buildPrompt(from: messages).count / 4
    }

    #if canImport(FoundationModels)
    private func ensureSession() async throws -> LanguageModelSession {
        lock.lock()
        if let s = session {
            lock.unlock()
            return s
        }
        lock.unlock()
        try await load()
        lock.lock(); defer { lock.unlock() }
        guard let s = session else { throw AIError.modelNotLoaded }
        return s
    }
    #endif

    private static func buildPrompt(from messages: [Message]) -> String {
        messages.map { m in
            switch m.role {
            case .system: return "[system] \(m.content)"
            case .user: return m.content
            case .assistant: return "[assistant] \(m.content)"
            case .tool: return "[tool:\(m.name ?? "")] \(m.content)"
            }
        }.joined(separator: "\n")
    }

    fileprivate static func extractText(from value: Any) -> String {
        if let s = value as? String { return s }
        let mirror = Mirror(reflecting: value)
        if let content = mirror.children.first(where: { $0.label == "content" })?.value {
            if let s = content as? String { return s }
            return String(describing: content)
        }
        return String(describing: value)
    }
}
