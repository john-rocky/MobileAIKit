import Foundation
import AIKit

public extension AIKit {
    /// High-accuracy transcription using WhisperKit (on-device Whisper via CoreML).
    /// - Parameters:
    ///   - audio: audio attachment (file URL or in-memory data).
    ///   - model: optional Whisper model variant. Pass `nil` to let WhisperKit pick
    ///            the best-matching model for the device (e.g. `"large-v3-v20240930_626MB"`,
    ///            `"base"`, `"small"`, `"medium"`).
    ///   - language: ISO 639-1 code (e.g. `"en"`, `"ja"`). `nil` enables language detection.
    static func transcribeWithWhisper(
        audio: AudioAttachment,
        model: String? = nil,
        language: String? = nil
    ) async throws -> String {
        let stt = WhisperSpeechToText(config: .init(model: model, language: language))
        return try await stt.transcribe(audio: audio).text
    }

    /// Returns the full Whisper result, including per-segment timestamps and detected language.
    static func transcribeWithWhisperDetailed(
        audio: AudioAttachment,
        model: String? = nil,
        language: String? = nil,
        wordTimestamps: Bool = false
    ) async throws -> WhisperTranscription {
        let stt = WhisperSpeechToText(config: .init(
            model: model,
            language: language,
            wordTimestamps: wordTimestamps
        ))
        return try await stt.transcribe(audio: audio)
    }
}
