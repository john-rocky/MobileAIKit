import SwiftUI
import AIKit
import AIKitUI
import AIKitCoreMLLLM

@main
struct MobileAIKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var backend: (any AIBackend)?
    @State private var error: String?
    @State private var downloading = false
    @State private var status: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if let backend {
                    HomeView(backend: backend)
                } else if downloading {
                    VStack(spacing: 16) {
                        ProgressView {
                            Text("Gemma 4 E2B")
                        }
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                } else if let error {
                    VStack(spacing: 12) {
                        Text("Failed to prepare model").font(.headline)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button("Retry") { Task { await prepare() } }
                            .buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    VStack(spacing: 12) {
                        Text("LocalAIKit Demo").font(.largeTitle).bold()
                        Text("Downloads a small local model and gives you a full chat UI, RAG, voice, vision, and tools on-device.")
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Get started") { Task { await prepare() } }
                            .buttonStyle(.borderedProminent)
                    }.padding()
                }
            }
            .navigationTitle("AIKit")
        }
    }

    private func prepare() async {
        downloading = true
        error = nil
        let b = CoreMLLLMBackend(model: .gemma4e2b)
        b.progressHandler = { line in
            Task { @MainActor in self.status = line }
        }
        do {
            try await b.load()
            backend = b
        } catch {
            self.error = error.localizedDescription
        }
        downloading = false
    }
}
