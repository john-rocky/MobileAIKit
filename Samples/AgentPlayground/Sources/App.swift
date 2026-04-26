import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct AgentPlaygroundApp: App {
    private let backend = CoreMLAgentBackend()

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
