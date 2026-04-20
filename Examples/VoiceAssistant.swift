import Foundation
import AIKit
#if canImport(AIKitSpeech) && canImport(Speech)
import AIKitSpeech

enum VoiceAssistant {
    @MainActor
    static func run(backend: any AIBackend) async throws {
        let session = ChatSession(backend: backend, systemPrompt: "You are a concise spoken assistant.")
        let stt = try SpeechToText(locale: Locale(identifier: "en-US"))
        let tts = TextToSpeech()

        guard await SpeechToText.requestAuthorization() else {
            throw AIError.permissionDenied("Speech recognition")
        }
        for try await interim in try stt.live() {
            if interim.isFinal {
                let transcript = interim.text
                print("User:", transcript)
                var reply = ""
                for try await chunk in session.sendStream(transcript) {
                    reply += chunk.delta
                }
                print("Assistant:", reply)
                await tts.speak(reply)
                break
            }
        }
    }
}
#endif
