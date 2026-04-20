import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct VoiceInterpreterApp: App {
    @State private var backend: (any AIBackend)?
    @State private var error: String?

    var body: some Scene {
        WindowGroup {
            if let backend {
                InterpreterView(backend: backend)
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                    Button("Retry") { Task { await bootstrap() } }.buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 60)).foregroundStyle(.tint)
                    Text("Voice Interpreter").font(.largeTitle).bold()
                    Text("Loading Gemma 4…")
                    ProgressView()
                }.padding().task { await bootstrap() }
            }
        }
    }

    private func bootstrap() async {
        error = nil
        do {
            let candidate = CoreMLLLMBackend(model: .gemma4e2b)
            try await candidate.load()
            await MainActor.run { self.backend = candidate }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
