#if canImport(SwiftUI)
import SwiftUI
import AIKit

/// Drop-in container that downloads + warms up a ``DownloadableBackend`` while
/// showing a real progress UI, then renders ``loaded`` once the backend is
/// ready. Works with both single-model backends (``CoreMLLLMBackend``) and
/// composite ones (``CoreMLAgentBackend``).
///
/// ```swift
/// @main
/// struct MyApp: App {
///     private let backend = CoreMLAgentBackend()  // E2B + FunctionGemma
///     var body: some Scene {
///         WindowGroup {
///             CoreMLModelLoaderView(
///                 backend: backend,
///                 appName: "MyApp",
///                 appIcon: "wand.and.stars"
///             ) {
///                 RootView(backend: backend)
///             }
///         }
///     }
/// }
/// ```
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct CoreMLModelLoaderView<Backend: DownloadableBackend, Loaded: View>: View {
    private let backend: Backend
    private let appName: String
    private let appIcon: String
    private let loaded: () -> Loaded

    @State private var phase: ModelLoadPhase = .idle

    public init(
        backend: Backend,
        appName: String,
        appIcon: String = "wand.and.stars",
        @ViewBuilder loaded: @escaping () -> Loaded
    ) {
        self.backend = backend
        self.appName = appName
        self.appIcon = appIcon
        self.loaded = loaded
    }

    public var body: some View {
        Group {
            if case .ready = phase {
                loaded()
            } else {
                ModelLoaderSetupView(
                    appName: appName,
                    appIcon: appIcon,
                    modelName: backend.displayModelName,
                    modelSize: backend.displayModelSize,
                    phase: phase
                ) {
                    Task { await bootstrap() }
                }
                .task {
                    if case .idle = phase { await bootstrap() }
                }
            }
        }
    }

    @MainActor
    private func bootstrap() async {
        phase = .idle
        do {
            try await backend.bootstrap { newPhase in
                Task { @MainActor in
                    phase = newPhase
                }
            }
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Setup view

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct ModelLoaderSetupView: View {
    let appName: String
    let appIcon: String
    let modelName: String
    let modelSize: String?
    let phase: ModelLoadPhase
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: appIcon)
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(appName)
                .font(.largeTitle.bold())

            VStack(spacing: 4) {
                Text(modelName).font(.headline)
                Label(sizeSubtitle, systemImage: "iphone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
                .frame(maxWidth: .infinity)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(24)
        .frame(maxWidth: 460)
    }

    private var sizeSubtitle: String {
        if let modelSize { return "\(modelSize) · on-device" }
        return "on-device"
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            HStack(spacing: 8) {
                ProgressView()
                Text("Preparing…").foregroundStyle(.secondary)
            }

        case .downloading(let fraction, let status):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Downloading", systemImage: "icloud.and.arrow.down")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(percentLabel(fraction))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: max(0, min(fraction, 1)))
                Text(status)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Label("Keep the app on Wi-Fi. Resumes if interrupted.", systemImage: "wifi")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

        case .warmingUp(let status):
            VStack(spacing: 8) {
                ProgressView()
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("First load takes 10–30 s on the ANE.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

        case .ready:
            EmptyView()

        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text("Setup failed").font(.headline)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func percentLabel(_ fraction: Double) -> String {
        let clamped = max(0, min(fraction, 1))
        return String(format: "%.0f%%", clamped * 100)
    }
}
#endif
