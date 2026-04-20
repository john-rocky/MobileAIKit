import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct SceneReaderApp: App {
    @State private var backend: (any AIBackend)?
    @State private var error: String?

    var body: some Scene {
        WindowGroup {
            if let backend {
                SceneReaderView(backend: backend)
            } else if let error {
                VStack {
                    Text("Setup failed").font(.headline)
                    Text(error).foregroundStyle(.secondary).padding()
                    Button("Retry") { Task { await boot() } }.buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "eye.fill").font(.system(size: 60)).foregroundStyle(.tint)
                    Text("Preparing Gemma 4…"); ProgressView()
                }.task { await boot() }
            }
        }
    }

    @MainActor
    private func boot() async {
        do {
            let b = CoreMLLLMBackend(model: .gemma4e2b)
            try await b.load()
            self.backend = b
        } catch {
            self.error = error.localizedDescription
        }
    }
}
