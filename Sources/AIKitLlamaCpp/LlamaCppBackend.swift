import Foundation
import AIKit
import llama

public final class LlamaCppBackend: AIBackend, @unchecked Sendable {
    public let info: BackendInfo
    public let modelPath: URL
    public let template: ChatTemplate
    public var contextLength: Int
    public var gpuLayers: Int32

    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private var vocab: OpaquePointer?
    private var sampler: OpaquePointer?
    private let lock = NSLock()
    private static var backendInitialized: Bool = {
        llama_backend_init()
        return true
    }()

    public init(
        modelPath: URL,
        template: ChatTemplate? = nil,
        contextLength: Int = 4096,
        gpuLayers: Int32 = 99
    ) {
        _ = Self.backendInitialized
        self.modelPath = modelPath
        self.template = template ?? ChatTemplate.auto(name: modelPath.lastPathComponent)
        self.contextLength = contextLength
        self.gpuLayers = gpuLayers
        self.info = BackendInfo(
            name: "llama.cpp.\(modelPath.lastPathComponent)",
            version: "1.0",
            capabilities: [.textGeneration, .streaming, .chatTemplate, .tokenization, .logitsAccess, .statefulSession],
            contextLength: contextLength,
            preferredDevice: "Metal"
        )
    }

    deinit {
        if let sampler { llama_sampler_free(sampler) }
        if let ctx { llama_free(ctx) }
        if let model { llama_model_free(model) }
    }

    public var isLoaded: Bool {
        get async { model != nil && ctx != nil }
    }

    public func load() async throws {
        lock.lock()
        defer { lock.unlock() }
        if model != nil && ctx != nil { return }

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = gpuLayers

        guard let loaded = modelPath.withUnsafeFileSystemRepresentation({ cstr -> OpaquePointer? in
            guard let cstr else { return nil }
            return llama_model_load_from_file(cstr, modelParams)
        }) else {
            throw AIError.modelLoadFailed("llama_model_load_from_file returned nil")
        }
        self.model = loaded
        self.vocab = llama_model_get_vocab(loaded)

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(contextLength)
        ctxParams.n_batch = 512
        ctxParams.n_threads = Int32(min(8, ProcessInfo.processInfo.processorCount))
        ctxParams.n_threads_batch = ctxParams.n_threads

        guard let context = llama_init_from_model(loaded, ctxParams) else {
            llama_model_free(loaded)
            self.model = nil
            throw AIError.modelLoadFailed("llama_init_from_model returned nil")
        }
        self.ctx = context

        var sparams = llama_sampler_chain_default_params()
        sparams.no_perf = true
        let chain = llama_sampler_chain_init(sparams)
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.95, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(0.7))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        self.sampler = chain
    }

    public func unload() async {
        lock.lock()
        defer { lock.unlock() }
        if let sampler { llama_sampler_free(sampler); self.sampler = nil }
        if let ctx { llama_free(ctx); self.ctx = nil }
        if let model { llama_model_free(model); self.model = nil }
        self.vocab = nil
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        try await load()
        guard let ctx, let model, let vocab else { throw AIError.modelNotLoaded }

        let rendered = template.render(messages, addGenerationPrompt: true)
        configureSampler(config: config)
        let tokens = try tokenize(rendered, bos: true, special: true, vocab: vocab)
        try decodeBatch(tokens: tokens, ctx: ctx)

        let prefillEnd = Date()
        var generated: [llama_token] = []
        let startToken = Int32(tokens.count)
        let maxTokens = config.maxTokens
        let stops = config.stopSequences + template.stopSequences
        var output = ""
        let decodeStart = Date()

        var singleToken: [llama_token] = [0]
        for i in 0..<Int32(maxTokens) {
            try Task.checkCancellation()
            guard let sampler = self.sampler else { break }
            let token = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            generated.append(token)
            let piece = try tokenToPiece(token, vocab: vocab)
            output += piece
            if stops.contains(where: { output.hasSuffix($0) }) { break }
            _ = i
            _ = startToken
            singleToken[0] = token
            let rc = singleToken.withUnsafeMutableBufferPointer { buf -> Int32 in
                let batch = llama_batch_get_one(buf.baseAddress, 1)
                return llama_decode(ctx, batch)
            }
            if rc != 0 { break }
        }
        let decodeEnd = Date()

        let usage = GenerationUsage(
            promptTokens: tokens.count,
            completionTokens: generated.count,
            prefillTimeSeconds: prefillEnd.timeIntervalSince(decodeStart) >= 0 ? 0 : 0,
            decodeTimeSeconds: decodeEnd.timeIntervalSince(decodeStart)
        )
        return GenerationResult(message: .assistant(output), usage: usage, finishReason: generated.count >= maxTokens ? .length : .stop)
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
                    guard let ctx = self.ctx, let vocab = self.vocab else {
                        throw AIError.modelNotLoaded
                    }
                    let rendered = self.template.render(messages, addGenerationPrompt: true)
                    self.configureSampler(config: config)
                    let tokens = try self.tokenize(rendered, bos: true, special: true, vocab: vocab)
                    try self.decodeBatch(tokens: tokens, ctx: ctx)

                    let stops = config.stopSequences + self.template.stopSequences
                    var accumulated = ""
                    var singleToken: [llama_token] = [0]
                    for i in 0..<Int32(config.maxTokens) {
                        if Task.isCancelled { break }
                        guard let sampler = self.sampler else { break }
                        let token = llama_sampler_sample(sampler, ctx, -1)
                        if llama_vocab_is_eog(vocab, token) { break }
                        let piece = try self.tokenToPiece(token, vocab: vocab)
                        accumulated += piece
                        continuation.yield(GenerationChunk(delta: piece))

                        if stops.contains(where: { accumulated.hasSuffix($0) }) { break }

                        singleToken[0] = token
                        let rc = singleToken.withUnsafeMutableBufferPointer { buf -> Int32 in
                            let batch = llama_batch_get_one(buf.baseAddress, 1)
                            return llama_decode(ctx, batch)
                        }
                        _ = i
                        if rc != 0 { break }
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
        guard let vocab else { throw AIError.modelNotLoaded }
        let rendered = template.render(messages, addGenerationPrompt: false)
        return try tokenize(rendered, bos: true, special: true, vocab: vocab).count
    }

    private func configureSampler(config: GenerationConfig) {
        if let existing = sampler {
            llama_sampler_free(existing)
        }
        var sparams = llama_sampler_chain_default_params()
        sparams.no_perf = true
        let chain = llama_sampler_chain_init(sparams)
        if config.topK > 0 {
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(Int32(config.topK)))
        }
        if config.topP < 1.0 {
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(config.topP, 1))
        }
        llama_sampler_chain_add(chain, llama_sampler_init_temp(config.temperature))
        let seed = config.seed.map { UInt32(truncatingIfNeeded: $0) } ?? UInt32.random(in: 0...UInt32.max)
        llama_sampler_chain_add(chain, llama_sampler_init_dist(seed))
        self.sampler = chain
    }

    private func tokenize(_ text: String, bos: Bool, special: Bool, vocab: OpaquePointer) throws -> [llama_token] {
        let utf8 = Array(text.utf8CString)
        let nTokens = -llama_tokenize(vocab, utf8, Int32(utf8.count - 1), nil, 0, bos, special)
        guard nTokens >= 0 else { throw AIError.generationFailed("tokenize failed") }
        var tokens = [llama_token](repeating: 0, count: Int(nTokens))
        let r = llama_tokenize(vocab, utf8, Int32(utf8.count - 1), &tokens, nTokens, bos, special)
        if r < 0 { throw AIError.generationFailed("tokenize failed") }
        return Array(tokens.prefix(Int(r)))
    }

    private func decodeBatch(tokens: [llama_token], ctx: OpaquePointer) throws {
        var mutable = tokens
        let batch = mutable.withUnsafeMutableBufferPointer { buf -> llama_batch in
            llama_batch_get_one(buf.baseAddress, Int32(buf.count))
        }
        let rc = llama_decode(ctx, batch)
        if rc != 0 { throw AIError.generationFailed("decode failed with rc=\(rc)") }
    }

    private func tokenToPiece(_ token: llama_token, vocab: OpaquePointer) throws -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        let n = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, true)
        if n < 0 {
            buffer = [CChar](repeating: 0, count: Int(-n) + 1)
            let n2 = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, true)
            if n2 < 0 { throw AIError.generationFailed("token_to_piece failed") }
            return String(cString: buffer)
        }
        buffer[Int(n)] = 0
        return String(cString: buffer)
    }
}
