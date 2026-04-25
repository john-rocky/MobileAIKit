import SwiftUI
import AIKit
import AIKitUI
import AIKitCoreMLLLM

@main
struct MobileAIKitDemoApp: App {
    private let backend = CoreMLLLMBackend(model: .gemma4e2b)

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CoreMLModelLoaderView(
                    backend: backend,
                    appName: "LocalAIKit Demo",
                    appIcon: "sparkles"
                ) {
                    HomeView(backend: backend)
                }
                .navigationTitle("AIKit")
            }
        }
    }
}
