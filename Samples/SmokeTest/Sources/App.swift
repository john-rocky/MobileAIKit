import SwiftUI
import AIKit
import AIKitUI
import AIKitCoreMLLLM

@main
struct SmokeTestApp: App {
    private let backend = CoreMLLLMBackend(model: .gemma4e2b)

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CoreMLModelLoaderView(
                    backend: backend,
                    appName: "Smoke Test",
                    appIcon: "checkmark.seal.fill"
                ) {
                    SmokeTestView(backend: backend)
                }
                .navigationTitle("LocalAIKit smoke test")
            }
        }
    }
}
