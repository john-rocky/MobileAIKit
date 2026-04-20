import Foundation

public enum Rerankers {
    public static func mmr(
        lambda: Float = 0.5
    ) -> @Sendable (String, [RetrievedDocument]) async throws -> [RetrievedDocument] {
        return { query, candidates in
            guard !candidates.isEmpty else { return [] }
            var selected: [RetrievedDocument] = []
            var remaining = candidates
            while let next = pickNext(remaining: remaining, selected: selected, lambda: lambda) {
                selected.append(next)
                remaining.removeAll { $0.chunk.id == next.chunk.id }
            }
            _ = query
            return selected
        }
    }

    private static func pickNext(
        remaining: [RetrievedDocument],
        selected: [RetrievedDocument],
        lambda: Float
    ) -> RetrievedDocument? {
        guard !remaining.isEmpty else { return nil }
        if selected.isEmpty {
            return remaining.max { $0.score < $1.score }
        }
        return remaining.max { a, b in
            mmrScore(a, selected: selected, lambda: lambda) < mmrScore(b, selected: selected, lambda: lambda)
        }
    }

    private static func mmrScore(_ doc: RetrievedDocument, selected: [RetrievedDocument], lambda: Float) -> Float {
        let maxSim = selected.map { textSimilarity($0.text, doc.text) }.max() ?? 0
        return lambda * doc.score - (1 - lambda) * maxSim
    }

    private static func textSimilarity(_ a: String, _ b: String) -> Float {
        let setA = Set(a.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        let setB = Set(b.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        guard !setA.isEmpty || !setB.isEmpty else { return 0 }
        let intersect = setA.intersection(setB).count
        let union = setA.union(setB).count
        return union > 0 ? Float(intersect) / Float(union) : 0
    }

    public static func llmRerank(
        backend: any AIBackend
    ) -> @Sendable (String, [RetrievedDocument]) async throws -> [RetrievedDocument] {
        return { query, candidates in
            guard !candidates.isEmpty else { return [] }
            let items = candidates.enumerated().map { "\($0.offset): \($0.element.text.prefix(200))" }.joined(separator: "\n")
            struct Out: Decodable { let order: [Int] }
            let schema: JSONSchema = .object(
                properties: ["order": .array(items: .integer(minimum: 0, maximum: candidates.count - 1))],
                required: ["order"]
            )
            let out: Out = try await AIKit.extract(
                Out.self,
                from: "Query: \(query)\n\nCandidates:\n\(items)",
                schema: schema,
                instruction: "Re-rank candidates by relevance to the query. Return 'order' as indices from most relevant to least.",
                backend: backend
            )
            var reordered: [RetrievedDocument] = []
            var seen = Set<Int>()
            for i in out.order {
                if i >= 0 && i < candidates.count && !seen.contains(i) {
                    reordered.append(candidates[i])
                    seen.insert(i)
                }
            }
            for (i, c) in candidates.enumerated() where !seen.contains(i) {
                reordered.append(c)
            }
            return reordered
        }
    }
}
