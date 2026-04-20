import Foundation
import AIKit

#if canImport(Speech) && canImport(AVFoundation)
@MainActor
public extension VoiceAssistant {
    convenience init(
        backend: any AIBackend,
        locale: Locale = Locale(identifier: "en-US"),
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) throws {
        let stt = try SpeechToText(locale: locale)
        let tts = TextToSpeech(locale: locale)
        self.init(backend: backend, transcriber: stt, speaker: tts, systemPrompt: systemPrompt, config: config)
    }
}
#endif
