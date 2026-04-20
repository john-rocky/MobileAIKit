import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

public struct RetrievedDocument: Sendable, Hashable, Codable {
    public let chunk: Chunk
    public let score: Float
    public let keywordScore: Float
    public let vectorScore: Float

    public var text: String { chunk.text }
    public var source: String { chunk.source }

    public init(chunk: Chunk, score: Float, keywordScore: Float, vectorScore: Float) {
        self.chunk = chunk
        self.score = score
        self.keywordScore = keywordScore
        self.vectorScore = vectorScore
    }
}

public actor VectorIndex {
    public let embedder: any Embedder
    public let dimension: Int
    private var chunks: [Chunk] = []
    private var vectors: [[Float]] = []
    private var termFrequencies: [[String: Int]] = []
    private var inverseDocFreq: [String: Double] = [:]

    public init(embedder: any Embedder) {
        self.embedder = embedder
        self.dimension = embedder.dimension
    }

    public func add(_ chunks: [Chunk]) async throws {
        let vecs = try await embedder.embed(batch: chunks.map(\.text))
        for (i, c) in chunks.enumerated() {
            self.chunks.append(c)
            self.vectors.append(vecs[i])
            self.termFrequencies.append(Self.termFrequency(c.text))
        }
        rebuildIDF()
    }

    public func addDocument(text: String, source: String, chunker: Chunker = Chunker()) async throws {
        let chs = chunker.chunk(text, source: source)
        try await add(chs)
    }

    public func count() -> Int { chunks.count }

    public func clear() {
        chunks.removeAll()
        vectors.removeAll()
        termFrequencies.removeAll()
        inverseDocFreq.removeAll()
    }

    public func search(query: String, limit: Int = 8, vectorWeight: Float = 0.7) async throws -> [RetrievedDocument] {
        guard !chunks.isEmpty else { return [] }
        let queryVec = try await embedder.embed(query)
        let queryTerms = Self.termFrequency(query)

        var scores = [Float](repeating: 0, count: chunks.count)
        var vectorScores = [Float](repeating: 0, count: chunks.count)
        var keywordScores = [Float](repeating: 0, count: chunks.count)

        for i in 0..<chunks.count {
            let vs = Self.cosine(queryVec, vectors[i])
            vectorScores[i] = vs
            let ks = Float(Self.bm25Score(queryTerms: queryTerms, docTerms: termFrequencies[i], idf: inverseDocFreq, docLength: chunks[i].text.count))
            keywordScores[i] = ks
        }

        let maxKw = max(keywordScores.max() ?? 1, 1e-6)
        for i in 0..<chunks.count {
            let normalizedKw = keywordScores[i] / maxKw
            scores[i] = vectorWeight * vectorScores[i] + (1 - vectorWeight) * normalizedKw
        }

        let indexed = scores.enumerated().map { ($0.offset, $0.element) }
        let top = indexed.sorted { $0.1 > $1.1 }.prefix(limit)
        return top.map { idx, score in
            RetrievedDocument(
                chunk: chunks[idx],
                score: score,
                keywordScore: keywordScores[idx] / maxKw,
                vectorScore: vectorScores[idx]
            )
        }
    }

    private func rebuildIDF() {
        let total = Double(chunks.count)
        var df: [String: Int] = [:]
        for tf in termFrequencies {
            for k in tf.keys { df[k, default: 0] += 1 }
        }
        var idf: [String: Double] = [:]
        for (k, c) in df {
            idf[k] = log(1 + (total - Double(c) + 0.5) / (Double(c) + 0.5))
        }
        inverseDocFreq = idf
    }

    private static func termFrequency(_ text: String) -> [String: Int] {
        var tf: [String: Int] = [:]
        let tokens = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for t in tokens { tf[String(t), default: 0] += 1 }
        return tf
    }

    private static func bm25Score(queryTerms: [String: Int], docTerms: [String: Int], idf: [String: Double], docLength: Int, k1: Double = 1.5, b: Double = 0.75, avgDocLength: Double = 500) -> Double {
        var score: Double = 0
        for (q, _) in queryTerms {
            let f = Double(docTerms[q] ?? 0)
            let qIdf = idf[q] ?? 0
            let numerator = f * (k1 + 1)
            let denom = f + k1 * (1 - b + b * Double(docLength) / avgDocLength)
            if denom > 0 { score += qIdf * numerator / denom }
        }
        return score
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        #if canImport(Accelerate)
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        var na: Float = 0, nb: Float = 0
        vDSP_svesq(a, 1, &na, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &nb, vDSP_Length(b.count))
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom > 0 ? dot / denom : 0
        #else
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom > 0 ? dot / denom : 0
        #endif
    }
}
