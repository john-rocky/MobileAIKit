import Foundation
import AIKit
import CoreML
import CoreMLLLM

/// On-device sentence embedder powered by EmbeddingGemma-300M (Gemma 3
/// bidirectional encoder, 99.8% ANE residency, 768-d unit-norm output).
///
/// This is the **recommended** embedding path for LocalAIKit. Unlike the
/// bundled `NLEmbedder` (Apple NLEmbedding — word-vector averaging, ~300-d)
/// or `HashingEmbedder` (zero-setup hash trick), EmbeddingGemma produces
/// true sentence embeddings via a transformer encoder, with published
/// task-prefix + Matryoshka-truncation conventions.
///
/// ## Caveat
///
/// Requires a one-time ~295 MB download from HuggingFace. If you need a
/// zero-download fallback, use `NLEmbedder` or `HashingEmbedder`.
///
/// ## Usage
///
/// ```swift
/// let modelsDir = URL.documentsDirectory.appending(path: "models")
/// let embedder = EmbeddingGemmaEmbedder(
///     modelsDir: modelsDir,
///     task: .retrievalDocument  // prefix for the HF task taxonomy
/// )
/// let v = try await embedder.embed("Hello, world.")  // 768 floats, unit norm
/// ```
///
/// Matryoshka truncation lets you trade recall for storage — pass
/// `dimension: 512` / `256` / `128` to emit a shorter unit-norm prefix.
public final class EmbeddingGemmaEmbedder: Embedder, @unchecked Sendable {

    /// Where the EmbeddingGemma bundle comes from.
    public enum Source: Sendable {
        /// Pre-downloaded bundle directory (contains `encoder.mlmodelc` or `encoder.mlpackage`).
        case bundleURL(URL)
        /// Download from the default HuggingFace repo on first `load()` into
        /// `modelsDir/embeddinggemma-300m/`. Gated repos need `hfToken`.
        case download(modelsDir: URL, hfToken: String?)
    }

    public let dimension: Int
    public let source: Source
    public let task: EmbeddingGemma.Task?
    public let computeUnits: MLComputeUnits

    /// `nil` → full 768-d output; one of 512 / 256 / 128 → Matryoshka-truncated prefix.
    private let matryoshkaDim: Int?
    private var model: EmbeddingGemma?
    private let stateLock = NSLock()
    private let inferenceLock = NSLock()

    public init(
        source: Source,
        task: EmbeddingGemma.Task? = nil,
        dimension: Int? = nil,
        computeUnits: MLComputeUnits = .cpuAndNeuralEngine
    ) {
        self.source = source
        self.task = task
        self.matryoshkaDim = dimension
        self.computeUnits = computeUnits
        self.dimension = dimension ?? 768
    }

    /// Construct from a pre-downloaded bundle directory.
    public convenience init(
        bundleURL: URL,
        task: EmbeddingGemma.Task? = nil,
        dimension: Int? = nil,
        computeUnits: MLComputeUnits = .cpuAndNeuralEngine
    ) {
        self.init(
            source: .bundleURL(bundleURL),
            task: task,
            dimension: dimension,
            computeUnits: computeUnits
        )
    }

    /// Construct with lazy download: the bundle fetches from HuggingFace on
    /// first `load()` into `modelsDir/embeddinggemma-300m/`.
    public convenience init(
        modelsDir: URL,
        hfToken: String? = nil,
        task: EmbeddingGemma.Task? = nil,
        dimension: Int? = nil,
        computeUnits: MLComputeUnits = .cpuAndNeuralEngine
    ) {
        self.init(
            source: .download(modelsDir: modelsDir, hfToken: hfToken),
            task: task,
            dimension: dimension,
            computeUnits: computeUnits
        )
    }

    public var isLoaded: Bool { stateLock.withLock { model != nil } }

    public func load() async throws {
        try await load(onDownloadProgress: nil)
    }

    /// `load()` with a byte-level progress callback fired during the HuggingFace download.
    public func load(
        progress: @escaping @Sendable (Gemma3BundleDownloader.Progress) -> Void
    ) async throws {
        try await load(onDownloadProgress: progress)
    }

    private func load(
        onDownloadProgress: (@Sendable (Gemma3BundleDownloader.Progress) -> Void)?
    ) async throws {
        if stateLock.withLock({ model != nil }) { return }
        do {
            let loaded: EmbeddingGemma
            switch source {
            case .bundleURL(let url):
                loaded = try await EmbeddingGemma.load(bundleURL: url, computeUnits: computeUnits)
            case .download(let modelsDir, let token):
                loaded = try await EmbeddingGemma.downloadAndLoad(
                    modelsDir: modelsDir,
                    hfToken: token,
                    computeUnits: computeUnits,
                    onProgress: onDownloadProgress
                )
            }
            stateLock.withLock { self.model = loaded }
        } catch {
            throw AIError.modelLoadFailed(error.localizedDescription)
        }
    }

    public func unload() async {
        stateLock.withLock { model = nil }
    }

    public func embed(_ text: String) async throws -> [Float] {
        try await load()
        guard let model = stateLock.withLock({ self.model }) else { throw AIError.modelNotLoaded }
        let localTask = self.task
        let localDim = self.matryoshkaDim
        do {
            return try inferenceLock.withLock {
                try model.encode(text: text, task: localTask, dim: localDim)
            }
        } catch {
            throw AIError.generationFailed(error.localizedDescription)
        }
    }
}
