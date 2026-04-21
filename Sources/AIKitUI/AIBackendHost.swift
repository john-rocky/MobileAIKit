import SwiftUI
import AIKit

/// `@Observable` wrapper that owns an `AIBackend` instance for the lifetime of your app.
///
/// Load the model once, inject the host through the environment, and every SwiftUI view can
/// read `host.backend` without re-loading the model on each call.
///
/// ```swift
/// @main
/// struct MyApp: App {
///     @State private var host = AIBackendHost { CoreMLLLMBackend(model: .gemma4e2b) }
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environment(host)
///                 .task { await host.load() }
///         }
///     }
/// }
///
/// struct ContentView: View {
///     @Environment(AIBackendHost.self) private var host
///     var body: some View {
///         if let backend = host.backend {
///             AIChatView(session: ChatSession(backend: backend))
///         } else if host.isLoading {
///             ProgressView()
///         }
///     }
/// }
/// ```
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
@MainActor
@Observable
public final class AIBackendHost {
    public private(set) var backend: (any AIBackend)?
    public private(set) var isLoading: Bool = false
    public private(set) var error: String?
    public private(set) var loadedAt: Date?

    private let factory: @Sendable () async throws -> any AIBackend

    public init(factory: @Sendable @escaping () async throws -> any AIBackend) {
        self.factory = factory
    }

    /// Convenience for a backend that's cheap to construct synchronously.
    public convenience init(_ makeBackend: @Sendable @escaping () -> any AIBackend) {
        self.init(factory: { makeBackend() })
    }

    /// Loads the backend once. Subsequent calls are no-ops.
    public func load() async {
        guard backend == nil, !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let b = try await factory()
            try await b.load()
            self.backend = b
            self.loadedAt = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Frees the backend's weights. Call on memory-pressure or when your screen is dismissed.
    public func unload() async {
        if let b = backend { await b.unload() }
        backend = nil
        loadedAt = nil
    }

    /// Forces a fresh load (e.g. after swapping models).
    public func reload() async {
        await unload()
        await load()
    }

    /// Returns the loaded backend or throws `AIError.modelNotLoaded`.
    public func require() throws -> any AIBackend {
        guard let backend else { throw AIError.modelNotLoaded }
        return backend
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public extension View {
    /// Injects an `AIBackendHost` into the environment and ensures it's loaded when the view appears.
    func aiBackendHost(_ host: AIBackendHost) -> some View {
        self.environment(host)
            .task { await host.load() }
    }
}
