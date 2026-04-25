import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct SceneReaderApp: App {
    private let backend = CoreMLLLMBackend(model: .gemma4e2b)

    var body: some Scene {
        WindowGroup {
            CoreMLModelLoaderView(
                backend: backend,
                appName: "Scene Reader",
                appIcon: "eye.fill"
            ) {
                SceneReaderView(backend: backend)
            }
        }
    }
}
