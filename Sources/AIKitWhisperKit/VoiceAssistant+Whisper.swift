import Foundation
import AIKit

#if canImport(AVFoundation)
@MainActor
public extension VoiceAssistant {
    /// Build a voice assistant that uses WhisperKit for high-accuracy transcription.
    /// The speaker must be supplied separately (e.g. `TextToSpeech` from `AIKitSpeech`).
    convenience init(
        backend: any AIBackend,
        whisper: WhisperConfig = .init(),
        speaker: any VoiceSpeaker,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) {
        let stt = WhisperSpeechToText(config: whisper)
        self.init(
            backend: backend,
            transcriber: stt,
            speaker: speaker,
            systemPrompt: systemPrompt,
            config: config
        )
    }
}
#endif
