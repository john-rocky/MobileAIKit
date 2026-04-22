import Foundation
import AIKit
import AIKitCoreMLLLM

enum QuickStart {

    static func oneShot() async throws -> String {
        let backend = CoreMLLLMBackend(model: .gemma4e2b)
        return try await AIKit.chat("Explain Swift actors in one sentence.", backend: backend)
    }

    static func streaming() async throws {
        let backend = CoreMLLLMBackend(model: .gemma4e2b)
        for try await delta in AIKit.stream("Give me 3 haikus about oceans.", backend: backend) {
            print(delta, terminator: "")
        }
        print()
    }
}
