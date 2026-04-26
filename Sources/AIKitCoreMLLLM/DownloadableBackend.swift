import Foundation
import AIKit

/// Backend that can stream its download + warm-up progress to a UI.
///
/// Implemented by ``CoreMLLLMBackend`` (single model) and ``CoreMLAgentBackend``
/// (chat + tool router). ``CoreMLModelLoaderView`` is generic over this protocol.
public protocol DownloadableBackend: AIBackend {
    /// Human-readable model name shown above the loader's progress bar.
    var displayModelName: String { get }

    /// Human-readable size string (e.g. "3.1 GB"). `nil` when unknown
    /// (for example, when constructed from a local directory).
    var displayModelSize: String? { get }

    /// Run the full bootstrap (download → warm-up) and report each transition
    /// to `progress`. Returns when the backend is ready to `generate`.
    func bootstrap(
        progress: @Sendable @escaping (ModelLoadPhase) -> Void
    ) async throws
}

/// Phases reported by ``DownloadableBackend/bootstrap(progress:)``.
public enum ModelLoadPhase: Equatable, Sendable {
    case idle
    case downloading(fraction: Double, status: String)
    case warmingUp(status: String)
    case ready
    case failed(String)
}
