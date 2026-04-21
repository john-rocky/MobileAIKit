import Foundation
import AIKit
#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(AVFoundation)
public enum TTSQuality: Sendable, Hashable {
    /// Default compact voice (always available).
    case `default`
    /// Enhanced voice — higher quality, may require user install from Settings → Accessibility → Spoken Content.
    case enhanced
    /// Premium voice (iOS 16+) — highest quality neural voice, user install required.
    case premium
    /// Automatically select the highest-quality installed voice for the locale.
    case best
    /// Use a user-created Personal Voice (iOS 17+). Requires user authorization.
    case personal

    fileprivate var avQuality: AVSpeechSynthesisVoiceQuality? {
        switch self {
        case .default: return .default
        case .enhanced: return .enhanced
        case .premium: return .premium
        case .best, .personal: return nil
        }
    }
}

public final class TextToSpeech: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate, VoiceSpeaker {
    public func speak(_ text: String) async {
        await speakUtterance(text, locale: nil, voice: nil)
    }
    private let synthesizer = AVSpeechSynthesizer()
    public var defaultLocale: Locale
    public var rate: Float
    public var pitch: Float
    public var quality: TTSQuality
    private var finishContinuation: CheckedContinuation<Void, Never>?

    public init(
        locale: Locale = Locale(identifier: "en-US"),
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitch: Float = 1.0,
        quality: TTSQuality = .default
    ) {
        self.defaultLocale = locale
        self.rate = rate
        self.pitch = pitch
        self.quality = quality
        super.init()
        synthesizer.delegate = self
    }

    public func speakUtterance(
        _ text: String,
        locale: Locale? = nil,
        voice: AVSpeechSynthesisVoice? = nil
    ) async {
        let utter = AVSpeechUtterance(string: text)
        let targetLocale = locale ?? defaultLocale
        utter.voice = voice
            ?? Self.bestVoice(for: targetLocale, quality: quality)
            ?? AVSpeechSynthesisVoice(language: targetLocale.identifier)
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
        return voicesMatching(all, locale: locale)
    }

    /// Returns voices whose language prefix (e.g. "en", "ja") matches the locale's language code.
    public static func voicesMatching(_ voices: [AVSpeechSynthesisVoice], locale: Locale) -> [AVSpeechSynthesisVoice] {
        let prefix = locale.identifier.prefix(2)
        return voices.filter { $0.language.hasPrefix(prefix) }
    }

    /// Picks the best-quality installed voice for the locale. Returns `nil` if none match.
    /// For `.personal`, the caller must have previously requested authorization.
    public static func bestVoice(for locale: Locale, quality: TTSQuality) -> AVSpeechSynthesisVoice? {
        let pool = availableVoices(locale: locale)
        if pool.isEmpty { return nil }

        switch quality {
        case .personal:
            #if os(iOS) || os(visionOS)
            if #available(iOS 17.0, visionOS 1.0, *) {
                if let personal = pool.first(where: { $0.voiceTraits.contains(.isPersonalVoice) }) {
                    return personal
                }
            }
            #endif
            return pool.max(by: voiceOrdering)
        case .best:
            return pool.max(by: voiceOrdering)
        case .premium, .enhanced, .default:
            let target = quality.avQuality ?? .default
            if let exact = pool.first(where: { $0.quality == target }) {
                return exact
            }
            // Fall back to the best available when the requested tier is not installed.
            return pool.max(by: voiceOrdering)
        }
    }

    /// Requests Personal Voice authorization (iOS 17+). Returns `true` if granted.
    public static func requestPersonalVoiceAuthorization() async -> Bool {
        #if os(iOS) || os(visionOS)
        if #available(iOS 17.0, visionOS 1.0, *) {
            return await withCheckedContinuation { cont in
                AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
        }
        #endif
        return false
    }
}

private func voiceOrdering(_ a: AVSpeechSynthesisVoice, _ b: AVSpeechSynthesisVoice) -> Bool {
    rank(a) < rank(b)
}

private func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
    #if os(iOS) || os(visionOS)
    if #available(iOS 17.0, visionOS 1.0, *), voice.voiceTraits.contains(.isPersonalVoice) {
        return 4
    }
    #endif
    switch voice.quality {
    case .premium: return 3
    case .enhanced: return 2
    case .default: return 1
    @unknown default: return 0
    }
}
#endif
