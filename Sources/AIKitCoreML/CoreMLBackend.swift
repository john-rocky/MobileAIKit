import Foundation
import AIKit
import CoreML
import Tokenizers
import Hub

public final class CoreMLBackend: AIBackend, @unchecked Sendable {
    public struct Configuration: Sendable {
        public var modelURL: URL
        public var tokenizerRepoId: String?
        public var tokenizerDirectory: URL?
        public var template: ChatTemplate
        public var computeUnits: MLComputeUnits
        public var contextLength: Int
        public var logitsOutputName: String
        public var inputTokenName: String
        public var inputAttentionMaskName: String?
        public var kvCacheStateName: String?

        public init(
            modelURL: URL,
            tokenizerRepoId: String? = nil,
            tokenizerDirectory: URL? = nil,
            template: ChatTemplate? = nil,
            computeUnits: MLComputeUnits = .all,
            contextLength: Int = 2048,
            logitsOutputName: String = "logits",
            inputTokenName: String = "input_ids",
            inputAttentionMaskName: String? = "attention_mask",
            kvCacheStateName: String? = nil
        ) {
            self.modelURL = modelURL
            self.tokenizerRepoId = tokenizerRepoId
            self.tokenizerDirectory = tokenizerDirectory
            self.template = template ?? ChatTemplate.auto(name: modelURL.lastPathComponent)
            self.computeUnits = computeUnits
            self.contextLength = contextLength
            self.logitsOutputName = logitsOutputName
            self.inputTokenName = inputTokenName
            self.inputAttentionMaskName = inputAttentionMaskName
            self.kvCacheStateName = kvCacheStateName
        }
    }

    public let info: BackendInfo
    public let configuration: Configuration
    private var model: MLModel?
    private var tokenizer: (any Tokenizer)?
    private let lock = NSLock()

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.info = BackendInfo(
            name: "coreml.\(configuration.modelURL.lastPathComponent)",
            version: "1.0",
            capabilities: [.textGeneration, .streaming, .chatTemplate, .tokenization, .logitsAccess],
            contextLength: configuration.contextLength,
            preferredDevice: "ANE/GPU/CPU"
        )
    }

    public var isLoaded: Bool {
        get async { model != nil && tokenizer != nil }
    }

    public func load() async throws {
        lock.lock(); defer { lock.unlock() }
        if model != nil && tokenizer != nil { return }

        let config = MLModelConfiguration()
        config.computeUnits = configuration.computeUnits

        let compiledURL: URL
        if configuration.modelURL.pathExtension == "mlmodelc" {
            compiledURL = configuration.modelURL
        } else {
            compiledURL = try await MLModel.compileModel(at: configuration.modelURL)
        }
        let loaded = try MLModel(contentsOf: compiledURL, configuration: config)
        self.model = loaded

        if let repoId = configuration.tokenizerRepoId {
            self.tokenizer = try await AutoTokenizer.from(pretrained: repoId)
        } else if let dir = configuration.tokenizerDirectory {
            self.tokenizer = try await AutoTokenizer.from(modelFolder: dir)
        } else {
            throw AIError.tokenizerNotFound
        }
    }

    public func unload() async {
        lock.lock(); defer { lock.unlock() }
        model = nil
        tokenizer = nil
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        try await load()
        guard let model, let tokenizer else { throw AIError.modelNotLoaded }
        let prompt = configuration.template.render(messages, addGenerationPrompt: true)
        var tokens = tokenizer.encode(text: prompt)

        let start = Date()
        var generated: [Int] = []
        var output = ""
        let stops = config.stopSequences + configuration.template.stopSequences

        for _ in 0..<config.maxTokens {
            try Task.checkCancellation()
            let logits = try Self.forward(
                tokens: tokens,
                model: model,
                inputName: configuration.inputTokenName,
                maskName: configuration.inputAttentionMaskName,
                logitsOutputName: configuration.logitsOutputName,
                contextLength: configuration.contextLength
            )
            let next = Self.sample(logits: logits, config: config)
            tokens.append(next)
            generated.append(next)
            let decoded = tokenizer.decode(tokens: [next])
            output += decoded
            if stops.contains(where: { output.hasSuffix($0) }) { break }
            if let eos = tokenizer.eosTokenId, next == eos { break }
        }
        let elapsed = Date().timeIntervalSince(start)
        return GenerationResult(
            message: .assistant(output),
            usage: GenerationUsage(
                promptTokens: tokens.count - generated.count,
                completionTokens: generated.count,
                decodeTimeSeconds: elapsed
            ),
            finishReason: generated.count >= config.maxTokens ? .length : .stop
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
                    guard let model = self.model, let tokenizer = self.tokenizer else {
                        throw AIError.modelNotLoaded
                    }
                    let prompt = self.configuration.template.render(messages, addGenerationPrompt: true)
                    var tokens = tokenizer.encode(text: prompt)
                    let stops = config.stopSequences + self.configuration.template.stopSequences
                    var accumulated = ""
                    for _ in 0..<config.maxTokens {
                        if Task.isCancelled { break }
                        let logits = try Self.forward(
                            tokens: tokens,
                            model: model,
                            inputName: self.configuration.inputTokenName,
                            maskName: self.configuration.inputAttentionMaskName,
                            logitsOutputName: self.configuration.logitsOutputName,
                            contextLength: self.configuration.contextLength
                        )
                        let next = Self.sample(logits: logits, config: config)
                        tokens.append(next)
                        let piece = tokenizer.decode(tokens: [next])
                        accumulated += piece
                        continuation.yield(GenerationChunk(delta: piece))
                        if stops.contains(where: { accumulated.hasSuffix($0) }) { break }
                        if let eos = tokenizer.eosTokenId, next == eos { break }
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
        guard let tokenizer else { throw AIError.modelNotLoaded }
        let prompt = configuration.template.render(messages, addGenerationPrompt: false)
        return tokenizer.encode(text: prompt).count
    }

    public func embed(_ text: String) async throws -> [Float] {
        try await load()
        guard let model, let tokenizer else { throw AIError.modelNotLoaded }
        let tokens = tokenizer.encode(text: text)
        let logits = try Self.forward(
            tokens: tokens,
            model: model,
            inputName: configuration.inputTokenName,
            maskName: configuration.inputAttentionMaskName,
            logitsOutputName: configuration.logitsOutputName,
            contextLength: configuration.contextLength
        )
        let norm = logits.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        return norm > 0 ? logits.map { $0 / norm } : logits
    }

    private static func forward(
        tokens: [Int],
        model: MLModel,
        inputName: String,
        maskName: String?,
        logitsOutputName: String,
        contextLength: Int
    ) throws -> [Float] {
        let length = min(tokens.count, contextLength)
        let slice = Array(tokens.suffix(length))
        let shape = [1, length] as [NSNumber]
        let input = try MLMultiArray(shape: shape, dataType: .int32)
        for i in 0..<length {
            input[i] = NSNumber(value: Int32(slice[i]))
        }
        var featureDict: [String: MLFeatureValue] = [
            inputName: MLFeatureValue(multiArray: input)
        ]
        if let maskName {
            let mask = try MLMultiArray(shape: shape, dataType: .int32)
            for i in 0..<length { mask[i] = 1 }
            featureDict[maskName] = MLFeatureValue(multiArray: mask)
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: featureDict)
        let output = try model.prediction(from: provider)
        guard let logits = output.featureValue(for: logitsOutputName)?.multiArrayValue else {
            throw AIError.generationFailed("Missing logits output '\(logitsOutputName)'")
        }
        let vocab = Int(truncating: logits.shape.last ?? 0)
        let totalSeq = Int(truncating: logits.shape[logits.shape.count - 2])
        let lastIndex = (totalSeq - 1) * vocab
        let pointer = logits.dataPointer.bindMemory(to: Float.self, capacity: logits.count)
        return Array(UnsafeBufferPointer(start: pointer + lastIndex, count: vocab))
    }

    private static func sample(logits: [Float], config: GenerationConfig) -> Int {
        if config.temperature <= 0 {
            var best = 0
            var bestVal = -Float.infinity
            for (i, v) in logits.enumerated() where v > bestVal {
                bestVal = v; best = i
            }
            return best
        }
        let temp = max(config.temperature, 1e-5)
        let scaled = logits.map { $0 / temp }
        let maxL = scaled.max() ?? 0
        let exps = scaled.map { expf($0 - maxL) }
        let sum = exps.reduce(0, +)
        let probs = exps.map { $0 / sum }

        var indexed = probs.enumerated().map { ($0.offset, $0.element) }
        if config.topK > 0 && config.topK < probs.count {
            indexed.sort { $0.1 > $1.1 }
            indexed = Array(indexed.prefix(config.topK))
        }
        if config.topP < 1.0 {
            indexed.sort { $0.1 > $1.1 }
            var cum: Float = 0
            var cutoff = indexed.count
            for (i, kv) in indexed.enumerated() {
                cum += kv.1
                if cum >= config.topP { cutoff = i + 1; break }
            }
            indexed = Array(indexed.prefix(cutoff))
        }
        let total = indexed.reduce(Float(0)) { $0 + $1.1 }
        let r = Float.random(in: 0..<max(total, 1e-9))
        var acc: Float = 0
        for kv in indexed {
            acc += kv.1
            if r < acc { return kv.0 }
        }
        return indexed.last?.0 ?? 0
    }
}
