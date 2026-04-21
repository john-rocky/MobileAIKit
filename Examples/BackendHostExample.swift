import SwiftUI
import AIKit
import AIKitUI
import AIKitCoreMLLLM

// One model instance, held for the whole app. Every view reuses it — no reload cost.

@available(iOS 17.0, macOS 14.0, *)
struct MyGemmaApp: App {
    @State private var host = AIBackendHost { CoreMLLLMBackend(model: .gemma4e2b) }

    var body: some Scene {
        WindowGroup {
            RootScreen()
                .aiBackendHost(host)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct RootScreen: View {
    @Environment(AIBackendHost.self) private var host

    var body: some View {
        if let backend = host.backend {
            AIChatView(session: ChatSession(backend: backend, systemPrompt: "Be concise."))
        } else if host.isLoading {
            ProgressView("Loading Gemma 4…")
        } else if let error = host.error {
            Text("Failed: \(error)").foregroundStyle(.red)
        }
    }
}
