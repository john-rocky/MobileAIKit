import Foundation

public struct StreamingStructuredDecoder<T: Decodable & Sendable>: Sendable {
    public let decoder: StructuredDecoder

    public init(decoder: StructuredDecoder = .init()) {
        self.decoder = decoder
    }

    public func stream(
        from source: AsyncThrowingStream<GenerationChunk, Error>
    ) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var buffer = ""
                var lastValid: T?
                do {
                    for try await chunk in source {
                        buffer += chunk.delta
                        if let candidate = try? decoder.decode(T.self, from: buffer) {
                            if let previous = lastValid {
                                if String(describing: previous) != String(describing: candidate) {
                                    continuation.yield(candidate)
                                    lastValid = candidate
                                }
                            } else {
                                continuation.yield(candidate)
                                lastValid = candidate
                            }
                        }
                        if chunk.finished { break }
                    }
                    if let final = try? decoder.decode(T.self, from: buffer),
                       lastValid == nil || String(describing: lastValid!) != String(describing: final) {
                        continuation.yield(final)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
