import Foundation
import AIKit
import CoreML
import Tokenizers
import Hub

/// CoreML-backed sentence-transformer embedder.
///
/// Works against BERT-family sentence encoders (`all-MiniLM-L6-v2`,
/// `all-mpnet-base-v2`, `multilingual-e5-small`, …) that have been exported to
/// CoreML. Produces dense embeddings the rest of the kit (`DatabaseMemoryStore`,
/// `RAGPipeline`, `VectorIndex`) consumes.
///
/// ## Model contract
///
/// The CoreML model is expected to accept two inputs and produce one output:
///
/// | Name (default) | Shape | dtype |
/// |---|---|---|
/// | `input_ids` | `[1, seqLen]` | int32 |
/// | `attention_mask` | `[1, seqLen]` | int32 |
/// | `last_hidden_state` | `[1, seqLen, dim]` | float32 |
///
/// If the model pools internally and emits `sentence_embedding: [1, dim]`, set
/// ``Configuration/outputEmbeddingName`` accordingly and ``Configuration/pooling`` to
/// ``Configuration/Pooling/none``.
///
/// ## Exporting a model
///
/// ```python
/// import coremltools as ct
/// from sentence_transformers import SentenceTransformer
/// import torch
///
/// model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2").eval()
/// tokens = model.tokenize(["Hello world"])
/// example = (tokens["input_ids"].to(torch.int32),
///            tokens["attention_mask"].to(torch.int32))
/// traced = torch.jit.trace(model[0].auto_model, example)
/// ct.convert(
///     traced,
///     inputs=[ct.TensorType(name="input_ids", shape=(1, 256), dtype=np.int32),
///             ct.TensorType(name="attention_mask", shape=(1, 256), dtype=np.int32)],
/// ).save("MiniLM.mlpackage")
/// ```
public final class CoreMLEmbedder: Embedder, @unchecked Sendable {
    public struct Configuration: Sendable {
        public enum Pooling: Sendable, Hashable {
            /// Attention-masked mean of `last_hidden_state` — sentence-transformer default.
            case mean
            /// Take the `[CLS]` token only (first position).
            case cls
            /// Model already emits pooled `[1, dim]`. No further reduction.
            case none
        }

        public var modelURL: URL
        public var tokenizerRepoId: String?
        public var tokenizerDirectory: URL?
        public var dimension: Int
        public var maxSequenceLength: Int
        public var computeUnits: MLComputeUnits
        public var inputTokenName: String
        public var inputAttentionMaskName: String
        public var outputEmbeddingName: String
        public var pooling: Pooling
        public var normalize: Bool

        public init(
            modelURL: URL,
            tokenizerRepoId: String? = nil,
            tokenizerDirectory: URL? = nil,
            dimension: Int,
            maxSequenceLength: Int = 256,
            computeUnits: MLComputeUnits = .all,
            inputTokenName: String = "input_ids",
            inputAttentionMaskName: String = "attention_mask",
            outputEmbeddingName: String = "last_hidden_state",
            pooling: Pooling = .mean,
            normalize: Bool = true
        ) {
            self.modelURL = modelURL
            self.tokenizerRepoId = tokenizerRepoId
            self.tokenizerDirectory = tokenizerDirectory
            self.dimension = dimension
            self.maxSequenceLength = maxSequenceLength
            self.computeUnits = computeUnits
            self.inputTokenName = inputTokenName
            self.inputAttentionMaskName = inputAttentionMaskName
            self.outputEmbeddingName = outputEmbeddingName
            self.pooling = pooling
            self.normalize = normalize
        }

        // MARK: - Presets (dim + tokenizer known; caller provides modelURL)

        /// `sentence-transformers/all-MiniLM-L6-v2` — 384 dim, 256 max tokens.
        public static func miniLM_L6_v2(modelURL: URL) -> Configuration {
            Configuration(
                modelURL: modelURL,
                tokenizerRepoId: "sentence-transformers/all-MiniLM-L6-v2",
                dimension: 384,
                maxSequenceLength: 256
            )
        }

        /// `sentence-transformers/all-mpnet-base-v2` — 768 dim, 384 max tokens.
        public static func mpnetBase_v2(modelURL: URL) -> Configuration {
            Configuration(
                modelURL: modelURL,
                tokenizerRepoId: "sentence-transformers/all-mpnet-base-v2",
                dimension: 768,
                maxSequenceLength: 384
            )
        }

        /// `intfloat/multilingual-e5-small` — 384 dim, 512 max tokens, multilingual.
        public static func multilingualE5Small(modelURL: URL) -> Configuration {
            Configuration(
                modelURL: modelURL,
                tokenizerRepoId: "intfloat/multilingual-e5-small",
                dimension: 384,
                maxSequenceLength: 512
            )
        }

        /// `BAAI/bge-small-en-v1.5` — 384 dim, 512 max tokens.
        public static func bgeSmallEn_v15(modelURL: URL) -> Configuration {
            Configuration(
                modelURL: modelURL,
                tokenizerRepoId: "BAAI/bge-small-en-v1.5",
                dimension: 384,
                maxSequenceLength: 512
            )
        }
    }

    public let configuration: Configuration
    public var dimension: Int { configuration.dimension }

    private let lock = NSLock()
    private var model: MLModel?
    private var tokenizer: (any Tokenizer)?

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public convenience init(
        modelURL: URL,
        tokenizerRepoId: String,
        dimension: Int,
        maxSequenceLength: Int = 256
    ) {
        self.init(configuration: Configuration(
            modelURL: modelURL,
            tokenizerRepoId: tokenizerRepoId,
            dimension: dimension,
            maxSequenceLength: maxSequenceLength
        ))
    }

    public func load() async throws {
        lock.lock(); let cached = model; lock.unlock()
        if cached != nil { return }

        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = configuration.computeUnits

        let compiledURL: URL
        if configuration.modelURL.pathExtension == "mlmodelc" {
            compiledURL = configuration.modelURL
        } else {
            compiledURL = try await MLModel.compileModel(at: configuration.modelURL)
        }
        let loaded = try MLModel(contentsOf: compiledURL, configuration: mlConfig)

        let tok: any Tokenizer
        if let repoId = configuration.tokenizerRepoId {
            tok = try await AutoTokenizer.from(pretrained: repoId)
        } else if let dir = configuration.tokenizerDirectory {
            tok = try await AutoTokenizer.from(modelFolder: dir)
        } else {
            throw AIError.tokenizerNotFound
        }

        lock.lock()
        self.model = loaded
        self.tokenizer = tok
        lock.unlock()
    }

    public func unload() {
        lock.lock()
        model = nil
        tokenizer = nil
        lock.unlock()
    }

    public func embed(_ text: String) async throws -> [Float] {
        try await load()
        lock.lock(); let mdl = model; let tok = tokenizer; lock.unlock()
        guard let mdl, let tok else { throw AIError.modelNotLoaded }
        return try Self.run(text, model: mdl, tokenizer: tok, config: configuration)
    }

    public func embed(batch: [String]) async throws -> [[Float]] {
        try await load()
        lock.lock(); let mdl = model; let tok = tokenizer; lock.unlock()
        guard let mdl, let tok else { throw AIError.modelNotLoaded }
        var out: [[Float]] = []
        out.reserveCapacity(batch.count)
        for t in batch {
            out.append(try Self.run(t, model: mdl, tokenizer: tok, config: configuration))
        }
        return out
    }

    // MARK: - Core inference

    private static func run(
        _ text: String,
        model: MLModel,
        tokenizer: any Tokenizer,
        config: Configuration
    ) throws -> [Float] {
        let ids = tokenizer.encode(text: text)
        let seqLen = config.maxSequenceLength
        let realLen = min(ids.count, seqLen)
        // BERT-family pad token is conventionally id 0; attention_mask=0 means the
        // model ignores the position anyway so the concrete value is immaterial.
        let padId: Int = 0

        let shape: [NSNumber] = [1, NSNumber(value: seqLen)]
        let tokenArray = try MLMultiArray(shape: shape, dataType: .int32)
        let maskArray = try MLMultiArray(shape: shape, dataType: .int32)
        for i in 0..<seqLen {
            if i < realLen {
                tokenArray[i] = NSNumber(value: Int32(ids[i]))
                maskArray[i] = 1
            } else {
                tokenArray[i] = NSNumber(value: Int32(padId))
                maskArray[i] = 0
            }
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: [
            config.inputTokenName: MLFeatureValue(multiArray: tokenArray),
            config.inputAttentionMaskName: MLFeatureValue(multiArray: maskArray)
        ])
        let output = try model.prediction(from: provider)
        guard let raw = output.featureValue(for: config.outputEmbeddingName)?.multiArrayValue else {
            throw AIError.generationFailed("Missing embedding output '\(config.outputEmbeddingName)'")
        }

        let pooled = pool(raw, pooling: config.pooling, realLen: realLen, dim: config.dimension)
        return config.normalize ? l2normalize(pooled) : pooled
    }

    private static func pool(
        _ array: MLMultiArray,
        pooling: Configuration.Pooling,
        realLen: Int,
        dim: Int
    ) -> [Float] {
        let rank = array.shape.count
        // Already pooled `[1, dim]`
        if pooling == .none || rank == 2 {
            return readFloats(array, offset: 0, count: dim)
        }
        // `[1, seqLen, dim]`
        let seqLen = Int(truncating: array.shape[1])
        switch pooling {
        case .cls:
            return readFloats(array, offset: 0, count: dim)
        case .mean:
            var acc = [Float](repeating: 0, count: dim)
            let validLen = max(1, min(realLen, seqLen))
            let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
            for t in 0..<validLen {
                let base = t * dim
                for d in 0..<dim { acc[d] += pointer[base + d] }
            }
            let inv = 1.0 / Float(validLen)
            for d in 0..<dim { acc[d] *= inv }
            return acc
        case .none:
            return readFloats(array, offset: 0, count: dim)
        }
    }

    private static func readFloats(_ array: MLMultiArray, offset: Int, count: Int) -> [Float] {
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        return Array(UnsafeBufferPointer(start: pointer + offset, count: count))
    }

    private static func l2normalize(_ v: [Float]) -> [Float] {
        let norm = v.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }
}
