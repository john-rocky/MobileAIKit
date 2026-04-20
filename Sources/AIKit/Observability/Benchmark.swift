import Foundation

public struct BenchmarkRun: Sendable, Hashable, Codable {
    public let backend: String
    public let prompt: String
    public let completionTokens: Int
    public let promptTokens: Int
    public let prefillSeconds: Double
    public let decodeSeconds: Double
    public let tokensPerSecond: Double
    public let firstTokenSeconds: Double
    public let runAt: Date
    public let deviceModel: String
}

public actor BenchmarkRecorder {
    public private(set) var runs: [BenchmarkRun] = []

    public init() {}

    public func record(_ run: BenchmarkRun) { runs.append(run) }

    public func run(
        name: String,
        backend: any AIBackend,
        prompts: [String],
        config: GenerationConfig = GenerationConfig(maxTokens: 128, temperature: 0, stream: true)
    ) async throws -> [BenchmarkRun] {
        var results: [BenchmarkRun] = []
        for prompt in prompts {
            let start = Date()
            var firstTokenTime: Date?
            var completionTokens = 0
            let stream = backend.stream(
                messages: [.user(prompt)],
                tools: [],
                config: config
            )
            for try await chunk in stream {
                if firstTokenTime == nil && !chunk.delta.isEmpty {
                    firstTokenTime = Date()
                }
                if !chunk.delta.isEmpty {
                    completionTokens += max(1, chunk.delta.split(separator: " ").count)
                }
                if chunk.finished { break }
            }
            let end = Date()
            let prefill = firstTokenTime?.timeIntervalSince(start) ?? 0
            let decode = end.timeIntervalSince(firstTokenTime ?? start)
            let tps = decode > 0 ? Double(completionTokens) / decode : 0
            let run = BenchmarkRun(
                backend: name,
                prompt: prompt,
                completionTokens: completionTokens,
                promptTokens: (try? await backend.tokenCount(for: [.user(prompt)])) ?? 0,
                prefillSeconds: prefill,
                decodeSeconds: decode,
                tokensPerSecond: tps,
                firstTokenSeconds: prefill,
                runAt: Date(),
                deviceModel: Self.deviceModel()
            )
            results.append(run)
            runs.append(run)
        }
        return results
    }

    public func export() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(runs)) ?? Data()
    }

    public func clear() { runs.removeAll() }

    private static func deviceModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &model, &size, nil, 0)
        return String(cString: model)
    }
}

public struct GoldenCase: Sendable, Hashable, Codable {
    public let name: String
    public let input: String
    public let expected: String
    public let system: String?

    public init(name: String, input: String, expected: String, system: String? = nil) {
        self.name = name
        self.input = input
        self.expected = expected
        self.system = system
    }
}

public struct GoldenResult: Sendable, Hashable, Codable {
    public let name: String
    public let expected: String
    public let actual: String
    public let similarity: Double
    public let passed: Bool
}

public actor GoldenEvaluator {
    public let threshold: Double

    public init(threshold: Double = 0.5) {
        self.threshold = threshold
    }

    public func run(cases: [GoldenCase], backend: any AIBackend) async throws -> [GoldenResult] {
        var out: [GoldenResult] = []
        for c in cases {
            let answer = try await AIKit.chat(
                c.input,
                backend: backend,
                systemPrompt: c.system,
                config: .deterministic
            )
            let sim = Self.jaccardSimilarity(answer, c.expected)
            out.append(GoldenResult(name: c.name, expected: c.expected, actual: answer, similarity: sim, passed: sim >= threshold))
        }
        return out
    }

    private static func jaccardSimilarity(_ a: String, _ b: String) -> Double {
        let setA = Set(a.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        let setB = Set(b.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        guard !setA.isEmpty || !setB.isEmpty else { return 0 }
        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count
        return union == 0 ? 0 : Double(intersection) / Double(union)
    }
}
