import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct AgentPlaygroundApp: App {
    @State private var backend: (any AIBackend)?
    @State private var setupError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let backend {
                    ContentView(backend: backend)
                } else if let setupError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Setup failed").font(.headline)
                        Text(setupError)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") { Task { await bootstrap() } }
                            .buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 60))
                            .foregroundStyle(.tint)
                        Text("Agent Playground").font(.largeTitle).bold()
                        Text("Loading Gemma 4 on-device…")
                            .foregroundStyle(.secondary)
                        ProgressView()
                    }
                    .padding()
                    .task { await bootstrap() }
                }
            }
        }
    }

    @MainActor
    private func bootstrap() async {
        setupError = nil
        do {
            let backend = CoreMLLLMBackend(model: .gemma4e2b)
            try await backend.load()
            self.backend = backend
        } catch {
            self.setupError = error.localizedDescription
        }
    }
}
