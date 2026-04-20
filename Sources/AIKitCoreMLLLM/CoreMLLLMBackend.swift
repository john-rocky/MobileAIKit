import Foundation
import AIKit
import CoreML
import CoreMLLLM
import CoreGraphics
import ImageIO

public final class CoreMLLLMBackend: AIBackend, @unchecked Sendable {
    public enum Source: Sendable {
        case directory(URL)
        case model(CoreMLLLM.ModelDownloader.ModelInfo)
    }

    public let info: BackendInfo
    public let source: Source
    public let computeUnits: MLComputeUnits
    public var progressHandler: (@Sendable (String) -> Void)?

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
            capabilities: [.textGeneration, .streaming, .vision, .audioInput, .chatTemplate, .statefulSession],
            contextLength: 8192,
            preferredDevice: "ANE"
        )
    }

    public convenience init(directory: URL, computeUnits: MLComputeUnits = .cpuAndNeuralEngine) {
        self.init(source: .directory(directory), computeUnits: computeUnits)
    }

    public convenience init(model: CoreMLLLM.ModelDownloader.ModelInfo, computeUnits: MLComputeUnits = .cpuAndNeuralEngine) {
        self.init(source: .model(model), computeUnits: computeUnits)
    }

    public var isLoaded: Bool {
        get async { llm != nil }
    }

    public func load() async throws {
        lock.lock(); let existing = llm; lock.unlock()
        if existing != nil { return }
        do {
            let loaded: CoreMLLLM
            switch source {
            case .directory(let url):
                loaded = try await CoreMLLLM.load(from: url, computeUnits: computeUnits, onProgress: progressHandler)
            case .model(let info):
                loaded = try await CoreMLLLM.load(model: info, computeUnits: computeUnits, onProgress: progressHandler)
            }
            lock.lock(); self.llm = loaded; lock.unlock()
        } catch {
            throw AIError.modelLoadFailed(error.localizedDescription)
        }
    }

    public func unload() async {
        lock.lock(); llm = nil; lock.unlock()
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        try await load()
        guard let llm = llm else { throw AIError.modelNotLoaded }
        let (mapped, image, audio) = try await Self.prepare(messages)
        let start = Date()
        let output = try await llm.generate(
            mapped,
            image: image,
            audio: audio,
            maxTokens: config.maxTokens
        )
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
                    guard let llm = self.llm else { throw AIError.modelNotLoaded }
                    let (mapped, image, audio) = try await Self.prepare(messages)
                    let video = Self.firstVideoURL(in: messages)
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
                    for await piece in stream {
                        if Task.isCancelled { break }
                        continuation.yield(GenerationChunk(delta: piece))
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
                default:
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
