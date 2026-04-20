import Foundation

public struct Candidate: Sendable, Hashable {
    public let text: String
    public let seed: UInt64
    public let score: Double?
}

public enum MultiCandidate {
    public static func bestOfN(
        backend: any AIBackend,
        messages: [Message],
        config: GenerationConfig = .default,
        n: Int,
        scorer: @Sendable (String) async throws -> Double
    ) async throws -> Candidate {
        precondition(n > 0)
        var bestCandidate: Candidate?
        var bestScore = -Double.infinity
        for i in 0..<n {
            var c = config
            c.seed = UInt64(i &* 17 &+ 31)
            let result = try await backend.generate(messages: messages, tools: [], config: c)
            let score = try await scorer(result.message.content)
            if score > bestScore {
                bestScore = score
                bestCandidate = Candidate(text: result.message.content, seed: c.seed ?? 0, score: score)
            }
        }
        return bestCandidate ?? Candidate(text: "", seed: 0, score: nil)
    }

    public static func parallelBestOfN(
        backend: any AIBackend,
        messages: [Message],
        config: GenerationConfig = .default,
        n: Int,
        scorer: @Sendable (String) async throws -> Double
    ) async throws -> Candidate {
        precondition(n > 0)
        let results = try await withThrowingTaskGroup(of: Candidate.self) { group in
            for i in 0..<n {
                group.addTask {
                    var c = config
                    c.seed = UInt64(i &* 17 &+ 31)
                    let result = try await backend.generate(messages: messages, tools: [], config: c)
                    let score = try await scorer(result.message.content)
                    return Candidate(text: result.message.content, seed: c.seed ?? 0, score: score)
                }
            }
            var collected: [Candidate] = []
            for try await c in group { collected.append(c) }
            return collected
        }
        return results.max { ($0.score ?? -.infinity) < ($1.score ?? -.infinity) } ?? results.first!
    }
}
