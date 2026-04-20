import SwiftUI
import AIKit
import AIKitUI
import AIKitLlamaCpp

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
    @State private var progress: Double = 0

    let descriptor = ModelCatalog.qwen2_5_0_5B_Q4

    var body: some View {
        NavigationStack {
            Group {
                if let backend {
                    HomeView(backend: backend)
                } else if downloading {
                    VStack(spacing: 16) {
                        ProgressView(value: progress) {
                            Text(descriptor.displayName)
                        }
                        Text("\(Int(progress * 100))%")
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
                        Text("MobileAIKit Demo").font(.largeTitle).bold()
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
        let downloader = ModelDownloader()
        do {
            let dir = try await downloader.ensure(descriptor) { p in
                Task { @MainActor in self.progress = p.fraction }
            }
            let fileURL = dir.appendingPathComponent(descriptor.files.first!.relativePath)
            backend = LlamaCppBackend(modelPath: fileURL, template: .chatML)
        } catch {
            self.error = error.localizedDescription
        }
        downloading = false
    }
}
