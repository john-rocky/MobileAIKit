import Foundation
import AIKit

#if canImport(Speech)
public extension AIKit {
    static func transcribe(
        audio: AudioAttachment,
        locale: Locale = Locale(identifier: "en-US")
    ) async throws -> String {
        let stt = try SpeechToText(locale: locale)
        let result = try await stt.transcribe(audio: audio)
        return result.text
    }
}
#endif

#if canImport(AVFoundation)
public extension AIKit {
    @MainActor
    static func speak(
        _ text: String,
        locale: Locale = Locale(identifier: "en-US"),
        quality: TTSQuality = .default
    ) async {
        let tts = TextToSpeech(locale: locale, quality: quality)
        await tts.speakUtterance(text, locale: locale)
    }

    /// Speak with the highest-quality installed voice for the locale.
    /// On a fresh device this still uses a default voice; install an Enhanced or
    /// Premium voice from Settings → Accessibility → Spoken Content → Voices for full quality.
    @MainActor
    static func speakHQ(
        _ text: String,
        locale: Locale = Locale(identifier: "en-US")
    ) async {
        await speak(text, locale: locale, quality: .best)
    }
}
#endif
