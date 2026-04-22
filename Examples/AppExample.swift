import SwiftUI
import AIKit
import AIKitUI
import AIKitCoreMLLLM

@available(iOS 17.0, macOS 14.0, *)
struct LocalAIKitExampleApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct RootView: View {
    @State private var session: ChatSession?
    @State private var status: String = "Preparing model…"
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    AIChatView(session: session).navigationTitle("AIKit demo")
                } else if let error {
                    VStack {
                        Text(error).foregroundStyle(.red)
                        Button("Retry") { Task { await prepare() } }
                    }
                } else {
                    ProgressView(status)
                }
            }
        }
        .task { await prepare() }
    }

    @MainActor
    private func prepare() async {
        let backend = CoreMLLLMBackend(model: .gemma4e2b)
        backend.progressHandler = { line in
            Task { @MainActor in self.status = line }
        }
        do {
            try await backend.load()
            self.session = ChatSession(backend: backend, systemPrompt: "You are a concise assistant.")
        } catch {
            self.error = error.localizedDescription
        }
    }
}
