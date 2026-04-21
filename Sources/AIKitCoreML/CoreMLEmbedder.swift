import Foundation
import AIKit
import CoreML
import Compression
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

    // MARK: - Download

    /// Resumable download of a zipped `.mlpackage` / `.mlmodelc` into the app's Caches
    /// directory, unpacked and returned ready for ``Configuration``.
    ///
    /// The library deliberately **does not bundle** any CoreML weights — sentence encoders
    /// run ~80–400 MB and not every consumer needs them. Call this once at first launch
    /// (or from `AIModelDownloadView`) and cache the returned `URL`.
    ///
    /// - Parameters:
    ///   - remoteURL: HTTPS URL to a `.zip` containing a top-level `.mlpackage` or `.mlmodelc`.
    ///   - cacheKey: Stable folder name under `Caches/CoreMLEmbedder/` — reuse the same key
    ///     to make the call idempotent.
    ///   - expectedBytes: Optional known archive size so the progress bar is accurate before
    ///     the first `Content-Length` arrives.
    ///   - progress: `0.0 … 1.0` download fraction.
    /// - Returns: The local `.mlpackage` / `.mlmodelc` URL you pass to ``Configuration``.
    public static func downloadZippedModel(
        from remoteURL: URL,
        cacheKey: String,
        expectedBytes: Int64? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let fm = FileManager.default
        let caches = try fm.url(
            for: .cachesDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let root = caches.appendingPathComponent("CoreMLEmbedder", isDirectory: true)
            .appendingPathComponent(cacheKey, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        if let existing = findModelBundle(in: root) {
            progress?(1.0)
            return existing
        }

        let tmpZip = root.appendingPathComponent("__download.zip")
        try await downloadWithProgress(
            from: remoteURL, to: tmpZip,
            expectedBytes: expectedBytes, progress: progress
        )
        try unzip(tmpZip, into: root)
        try? fm.removeItem(at: tmpZip)

        guard let bundle = findModelBundle(in: root) else {
            throw AIError.downloadFailed("Archive did not contain a .mlpackage / .mlmodelc")
        }
        return bundle
    }

    private static func findModelBundle(in dir: URL) -> URL? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return nil }
        // Prefer compiled .mlmodelc; fall back to .mlpackage.
        if let mlc = entries.first(where: { $0.pathExtension == "mlmodelc" }) { return mlc }
        if let pkg = entries.first(where: { $0.pathExtension == "mlpackage" }) { return pkg }
        // Some archives wrap the bundle in an extra directory. Look one level deeper.
        for sub in entries where (try? sub.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            if let inner = findModelBundle(in: sub) { return inner }
        }
        return nil
    }

    private static func downloadWithProgress(
        from url: URL,
        to dest: URL,
        expectedBytes: Int64?,
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        let partURL = dest.appendingPathExtension("part")
        var request = URLRequest(url: url)
        let existingSize: Int64 = (try? FileManager.default.attributesOfItem(
            atPath: partURL.path
        )[.size] as? NSNumber)?.int64Value ?? 0
        if existingSize > 0 {
            request.setValue("bytes=\(existingSize)-", forHTTPHeaderField: "Range")
        }
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIError.downloadFailed("HTTP \(String(describing: response))")
        }
        let total = (http.expectedContentLength > 0 ? http.expectedContentLength : 0)
            + existingSize
        let totalForProgress = max(total, expectedBytes ?? 0)

        if !FileManager.default.fileExists(atPath: partURL.path) {
            FileManager.default.createFile(atPath: partURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: partURL)
        try handle.seek(toOffset: UInt64(existingSize))
        defer { try? handle.close() }

        var buffer = Data(); buffer.reserveCapacity(1 << 20)
        var written: Int64 = existingSize
        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count >= (1 << 20) {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if totalForProgress > 0 {
                    progress?(min(1.0, Double(written) / Double(totalForProgress)))
                }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            written += Int64(buffer.count)
            if totalForProgress > 0 {
                progress?(min(1.0, Double(written) / Double(totalForProgress)))
            }
        }
        try handle.close()
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: partURL, to: dest)
        progress?(1.0)
    }

    private static func unzip(_ archive: URL, into dir: URL) throws {
        #if targetEnvironment(simulator) || os(macOS)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-xk", archive.path, dir.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw AIError.downloadFailed("ditto exited \(proc.terminationStatus)")
        }
        #else
        try extractZipNative(from: archive, into: dir)
        #endif
    }

    #if !(targetEnvironment(simulator) || os(macOS))
    /// Minimal STORED/DEFLATE zip extractor for iOS/visionOS/tvOS where `/usr/bin/ditto`
    /// isn't available. Tested against the standard `zip -r` layout HF uses.
    private static func extractZipNative(from zipURL: URL, into destDir: URL) throws {
        let data = try Data(contentsOf: zipURL)
        guard data.count > 22 else {
            throw AIError.downloadFailed("Zip too small")
        }
        var eocd = data.count - 22
        while eocd >= 0 {
            if data[eocd] == 0x50, data[eocd+1] == 0x4B, data[eocd+2] == 0x05, data[eocd+3] == 0x06 { break }
            eocd -= 1
        }
        guard eocd >= 0 else { throw AIError.downloadFailed("No EOCD in zip") }
        let cdOffset = Int(data[(eocd+16)..<(eocd+20)].withUnsafeBytes { $0.load(as: UInt32.self) })
        let cdCount = Int(data[(eocd+10)..<(eocd+12)].withUnsafeBytes { $0.load(as: UInt16.self) })
        var pos = cdOffset
        let fm = FileManager.default
        for _ in 0..<cdCount {
            guard pos + 46 <= data.count,
                  data[pos] == 0x50, data[pos+1] == 0x4B,
                  data[pos+2] == 0x01, data[pos+3] == 0x02 else { break }
            let compMethod = data[(pos+10)..<(pos+12)].withUnsafeBytes { $0.load(as: UInt16.self) }
            let compSize = Int(data[(pos+20)..<(pos+24)].withUnsafeBytes { $0.load(as: UInt32.self) })
            let uncompSize = Int(data[(pos+24)..<(pos+28)].withUnsafeBytes { $0.load(as: UInt32.self) })
            let nameLen = Int(data[(pos+28)..<(pos+30)].withUnsafeBytes { $0.load(as: UInt16.self) })
            let extraLen = Int(data[(pos+30)..<(pos+32)].withUnsafeBytes { $0.load(as: UInt16.self) })
            let commentLen = Int(data[(pos+32)..<(pos+34)].withUnsafeBytes { $0.load(as: UInt16.self) })
            let localOffset = Int(data[(pos+42)..<(pos+46)].withUnsafeBytes { $0.load(as: UInt32.self) })
            let name = String(data: data[(pos+46)..<(pos+46+nameLen)], encoding: .utf8) ?? ""
            let destPath = destDir.appendingPathComponent(name)
            if name.hasSuffix("/") {
                try fm.createDirectory(at: destPath, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(
                    at: destPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let lnl = Int(data[(localOffset+26)..<(localOffset+28)].withUnsafeBytes { $0.load(as: UInt16.self) })
                let lel = Int(data[(localOffset+28)..<(localOffset+30)].withUnsafeBytes { $0.load(as: UInt16.self) })
                let ds = localOffset + 30 + lnl + lel
                let payload = data[ds..<(ds + compSize)]
                if compMethod == 0 {
                    try Data(payload).write(to: destPath)
                } else if compMethod == 8 {
                    let inflated = try inflate(payload, expectedSize: uncompSize)
                    try inflated.write(to: destPath)
                } else {
                    throw AIError.downloadFailed("Unsupported zip compression \(compMethod)")
                }
            }
            pos += 46 + nameLen + extraLen + commentLen
        }
    }

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        var output = Data(count: max(expectedSize, 1))
        let written = output.withUnsafeMutableBytes { (outRaw: UnsafeMutableRawBufferPointer) -> Int in
            data.withUnsafeBytes { (inRaw: UnsafeRawBufferPointer) -> Int in
                guard let inBase = inRaw.baseAddress, let outBase = outRaw.baseAddress else { return 0 }
                return compression_decode_buffer(
                    outBase.assumingMemoryBound(to: UInt8.self), expectedSize,
                    inBase.assumingMemoryBound(to: UInt8.self), data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        if written == 0 { throw AIError.downloadFailed("zlib inflate failed") }
        output.removeSubrange(written..<output.count)
        return output
    }
    #endif

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
