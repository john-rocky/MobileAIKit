import Foundation
import AIKit
#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(AVFoundation)
public final class TextToSpeech: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    public var defaultLocale: Locale
    public var rate: Float
    public var pitch: Float
    private var finishContinuation: CheckedContinuation<Void, Never>?

    public init(
        locale: Locale = Locale(identifier: "en-US"),
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitch: Float = 1.0
    ) {
        self.defaultLocale = locale
        self.rate = rate
        self.pitch = pitch
        super.init()
        synthesizer.delegate = self
    }

    public func speak(
        _ text: String,
        locale: Locale? = nil,
        voice: AVSpeechSynthesisVoice? = nil
    ) async {
        let utter = AVSpeechUtterance(string: text)
        utter.voice = voice ?? AVSpeechSynthesisVoice(language: (locale ?? defaultLocale).identifier)
        utter.rate = rate
        utter.pitchMultiplier = pitch
        await withCheckedContinuation { continuation in
            self.finishContinuation = continuation
            synthesizer.speak(utter)
        }
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finishContinuation?.resume()
        finishContinuation = nil
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finishContinuation?.resume()
        finishContinuation = nil
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finishContinuation?.resume()
        finishContinuation = nil
    }

    public static func availableVoices(locale: Locale? = nil) -> [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
        guard let locale else { return all }
        return all.filter { $0.language.hasPrefix(locale.identifier.prefix(2)) }
    }
}
#endif
