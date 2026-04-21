import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

public protocol Embedder: Sendable {
    var dimension: Int { get }
    func embed(_ text: String) async throws -> [Float]
    func embed(batch: [String]) async throws -> [[Float]]
}

public extension Embedder {
    func embed(batch: [String]) async throws -> [[Float]] {
        var out: [[Float]] = []
        out.reserveCapacity(batch.count)
        for t in batch {
            out.append(try await embed(t))
        }
        return out
    }
}

#if canImport(NaturalLanguage)
public struct NLEmbedder: Embedder, @unchecked Sendable {
    // @unchecked: NLEmbedding is a reference type but its `vector(for:)` and
    // `dimension` are thread-safe per Apple's NaturalLanguage documentation.
    public let language: NLLanguage
    public let dimension: Int
    private let embedding: NLEmbedding

    public init(language: NLLanguage = .english) throws {
        self.language = language
        guard let emb = NLEmbedding.wordEmbedding(for: language) else {
            throw AIError.unsupportedCapability("NLEmbedding for \(language.rawValue)")
        }
        self.embedding = emb
        self.dimension = emb.dimension
    }

    public func embed(_ text: String) async throws -> [Float] {
        let tokens = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard !tokens.isEmpty else { return [Float](repeating: 0, count: dimension) }
        var acc = [Double](repeating: 0, count: dimension)
        var count = 0
        for t in tokens {
            if let vec = embedding.vector(for: t) {
                for i in 0..<dimension { acc[i] += vec[i] }
                count += 1
            }
        }
        let divisor = Double(max(count, 1))
        let result = acc.map { Float($0 / divisor) }
        return Self.l2normalize(result)
    }

    private static func l2normalize(_ v: [Float]) -> [Float] {
        let norm = v.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }
}
#endif

public struct HashingEmbedder: Embedder {
    public let dimension: Int

    public init(dimension: Int = 512) {
        self.dimension = dimension
    }

    public func embed(_ text: String) async throws -> [Float] {
        var v = [Float](repeating: 0, count: dimension)
        let tokens = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        for t in tokens {
            let h = Self.hash(t)
            let idx = Int(h % UInt64(dimension))
            let sign: Float = (h & 1) == 0 ? 1 : -1
            v[idx] += sign
        }
        let norm = v.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        if norm > 0 { for i in 0..<dimension { v[i] /= norm } }
        return v
    }

    private static func hash(_ s: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 {
            h ^= UInt64(b)
            h &*= 1099511628211
        }
        return h
    }
}
