import Foundation
import AIKit
#if canImport(AIKitCoreMLLLM)
import AIKitCoreMLLLM

enum CoreMLLLMExample {
    static func textGeneration(modelDirectory: URL) async throws -> String {
        let backend = CoreMLLLMBackend(directory: modelDirectory)
        return try await AIKit.chat(
            "Explain vector databases in a tweet.",
            backend: backend
        )
    }

    static func streamingResponse(modelDirectory: URL) async throws {
        let backend = CoreMLLLMBackend(directory: modelDirectory)
        for try await delta in AIKit.stream("Give three tips for on-device LLM apps.", backend: backend) {
            print(delta, terminator: "")
        }
        print()
    }
}
#endif
