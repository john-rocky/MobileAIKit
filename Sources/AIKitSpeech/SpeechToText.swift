import Foundation
import AIKit
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

public struct STTResult: Sendable, Hashable, Codable {
    public let text: String
    public let isFinal: Bool
    public let segments: [Segment]

    public struct Segment: Sendable, Hashable, Codable {
        public let substring: String
        public let confidence: Float
        public let timestamp: Double
        public let duration: Double
    }
}

#if canImport(Speech)
public final class SpeechToText: @unchecked Sendable {
    public let locale: Locale
    private let recognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    public init(locale: Locale = Locale(identifier: "en-US")) throws {
        self.locale = locale
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw AIError.unsupportedCapability("SFSpeechRecognizer(\(locale.identifier))")
        }
        self.recognizer = recognizer
    }

    public static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    public func transcribe(audio: AudioAttachment) async throws -> STTResult {
        let data = try audio.loadData()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let request = SFSpeechURLRecognitionRequest(url: tmp)
        request.shouldReportPartialResults = false
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                let best = result.bestTranscription
                let segs: [STTResult.Segment] = best.segments.map {
                    .init(substring: $0.substring, confidence: $0.confidence, timestamp: $0.timestamp, duration: $0.duration)
                }
                continuation.resume(returning: STTResult(text: best.formattedString, isFinal: true, segments: segs))
            }
        }
    }

    public func live() throws -> AsyncThrowingStream<STTResult, Error> {
        AsyncThrowingStream { continuation in
            do {
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                self.recognitionRequest = request

                #if canImport(AVFoundation) && !os(macOS)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                #endif

                let input = audioEngine.inputNode
                let format = input.outputFormat(forBus: 0)
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    request.append(buffer)
                }

                audioEngine.prepare()
                try audioEngine.start()

                recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let result else { return }
                    let best = result.bestTranscription
                    let segs: [STTResult.Segment] = best.segments.map {
                        .init(substring: $0.substring, confidence: $0.confidence, timestamp: $0.timestamp, duration: $0.duration)
                    }
                    continuation.yield(STTResult(text: best.formattedString, isFinal: result.isFinal, segments: segs))
                    if result.isFinal {
                        continuation.finish()
                    }
                }

                continuation.onTermination = { [weak self] _ in
                    self?.stop()
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    public func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
#endif
