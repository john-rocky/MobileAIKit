import Foundation
import AIKit

enum BenchmarkExample {
    static func compareBackends(_ backends: [any AIBackend]) async throws -> [BenchmarkRun] {
        let prompts = [
            "Write a haiku about ocean waves.",
            "Explain Transformer attention in one paragraph.",
            "List five ways to reduce mobile battery use."
        ]
        let recorder = BenchmarkRecorder()
        var all: [BenchmarkRun] = []
        for backend in backends {
            let runs = try await recorder.run(name: backend.info.name, backend: backend, prompts: prompts)
            all.append(contentsOf: runs)
        }
        return all
    }
}
