import Foundation
import AIKit
import AIKitLlamaCpp
import AIKitMLX
#if canImport(AIKitFoundationModels)
import AIKitFoundationModels
#endif

enum QuickStart {

    static func oneShot_llamaCpp(modelPath: URL) async throws -> String {
        let backend = LlamaCppBackend(modelPath: modelPath)
        return try await AIKit.chat("Explain Swift actors in one sentence.", backend: backend)
    }

    static func streaming_mlx() async throws {
        let backend = MLXBackend(
            modelId: "qwen-2.5-0.5b-instruct",
            hubRepoId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
        )
        for try await delta in AIKit.stream("Give me 3 haikus about oceans.", backend: backend) {
            print(delta, terminator: "")
        }
        print()
    }

    #if canImport(AIKitFoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    static func foundationModels_chat() async throws {
        let backend = FoundationModelsBackend(instructions: "Reply in under 20 words.")
        let answer = try await AIKit.chat("What is diffusion?", backend: backend)
        print(answer)
    }
    #endif
}
