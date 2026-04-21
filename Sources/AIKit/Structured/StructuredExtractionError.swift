import Foundation

/// Thrown by ``AIKit/extract(_:from:schema:instruction:backend:)`` and friends
/// when the model's output cannot be decoded into the requested type.
///
/// Unlike a bare `DecodingError`, this preserves `rawText` so apps can show the
/// user what the model actually said, log it to telemetry, or retry with a
/// refined prompt instead of making the user retake the photo.
public struct StructuredExtractionError: LocalizedError, Sendable {
    /// The full, unparsed text the model produced — including any fences, prose, or partial JSON.
    public let rawText: String
    /// The last decoding / parsing error that was hit.
    public let underlying: Error
    /// How many backend round-trips were made before giving up.
    public let attempts: Int

    public init(rawText: String, underlying: Error, attempts: Int = 1) {
        self.rawText = rawText
        self.underlying = underlying
        self.attempts = attempts
    }

    public var errorDescription: String? {
        "Structured extraction failed after \(attempts) attempt(s): \(underlying.localizedDescription)"
    }
}
