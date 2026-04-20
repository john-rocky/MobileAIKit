import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct MomentsApp: App {
    @State private var store: MomentStore?
    @State private var backend: (any AIBackend)?
    @State private var setupError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let store, let backend {
                    RootView(store: store, backend: backend)
                } else if let setupError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
                        Text("Setup failed").font(.headline)
                        Text(setupError).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                        Button("Retry") { Task { await bootstrap() } }.buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles.tv").font(.system(size: 60)).foregroundStyle(.tint)
                        Text("Moments").font(.largeTitle).bold()
                        Text("Preparing Gemma 4 on-device…")
                        ProgressView()
                    }.padding().task { await bootstrap() }
                }
            }
        }
    }

    @MainActor
    private func bootstrap() async {
        setupError = nil
        do {
            let store = try MomentStore()
            let backend = CoreMLLLMBackend(model: .gemma4e2b)
            try await backend.load()
            self.store = store
            self.backend = backend
        } catch {
            self.setupError = error.localizedDescription
        }
    }
}
