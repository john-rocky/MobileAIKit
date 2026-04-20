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
        locale: Locale = Locale(identifier: "en-US")
    ) async {
        let tts = TextToSpeech(locale: locale)
        await tts.speakUtterance(text, locale: locale)
    }
}
#endif
