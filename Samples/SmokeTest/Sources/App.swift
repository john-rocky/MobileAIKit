import SwiftUI
import AIKit
import AIKitUI
import AIKitCoreMLLLM

@main
struct SmokeTestApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var backend: (any AIBackend)?
    @State private var status: String = "Preparing Gemma 4 E2B…"
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let backend {
                    SmokeTestView(backend: backend)
                } else if let error {
                    VStack(spacing: 12) {
                        Text("Failed to load").font(.headline)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button("Retry") { Task { await boot() } }
                            .buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }.padding()
                }
            }
            .navigationTitle("LocalAIKit smoke test")
        }
        .task { await boot() }
    }

    @MainActor
    private func boot() async {
        error = nil
        let b = CoreMLLLMBackend(model: .gemma4e2b)
        b.progressHandler = { line in
            Task { @MainActor in self.status = line }
        }
        do {
            try await b.load()
            self.backend = b
        } catch {
            self.error = error.localizedDescription
        }
    }
}
