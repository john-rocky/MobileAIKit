import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct VoiceInterpreterApp: App {
    private let backend = CoreMLLLMBackend(model: .gemma4e2b)

    var body: some Scene {
        WindowGroup {
            CoreMLModelLoaderView(
                backend: backend,
                appName: "Voice Interpreter",
                appIcon: "bubble.left.and.bubble.right.fill"
            ) {
                InterpreterView(backend: backend)
            }
        }
    }
}
