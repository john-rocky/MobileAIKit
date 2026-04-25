import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct AgentPlaygroundApp: App {
    private let backend = CoreMLLLMBackend(model: .gemma4e2b)

    var body: some Scene {
        WindowGroup {
            CoreMLModelLoaderView(
                backend: backend,
                appName: "Agent Playground",
                appIcon: "wand.and.stars"
            ) {
                ContentView(backend: backend)
            }
        }
    }
}
