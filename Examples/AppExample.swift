import SwiftUI
import AIKit
import AIKitUI
import AIKitLlamaCpp

@available(iOS 17.0, macOS 14.0, *)
struct LocalAIKitExampleApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct RootView: View {
    let descriptor = ModelCatalog.qwen3_0_6B_Q4
    @State private var session: ChatSession?
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
                    AIModelDownloadView(descriptor: descriptor) { url in
                        Task { await start(at: url) }
                    }
                }
            }
        }
        .task { await prepare() }
    }

    private func prepare() async {
        let downloader = ModelDownloader()
        do {
            let dir = try await downloader.ensure(descriptor) { _ in }
            await start(at: dir)
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func start(at url: URL) async {
        let fileURL = url.appendingPathComponent(descriptor.files.first!.relativePath)
        let backend = LlamaCppBackend(modelPath: fileURL, template: .chatML)
        let session = ChatSession(backend: backend, systemPrompt: "You are a concise assistant.")
        self.session = session
    }
}
