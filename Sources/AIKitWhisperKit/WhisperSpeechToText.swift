import Foundation
import AIKit
import WhisperKit
#if canImport(AVFoundation)
import AVFoundation
#endif

public struct WhisperTranscription: Sendable, Hashable, Codable {
    public let text: String
    public let language: String
    public let segments: [Segment]

    public struct Segment: Sendable, Hashable, Codable {
        public let text: String
        public let start: Float
        public let end: Float
    }
}

public struct WhisperConfig: Sendable {
    public var model: String?
    public var modelRepo: String?
    public var language: String?
    public var task: Task
    public var temperature: Float
    public var wordTimestamps: Bool
    public var livePartialInterval: TimeInterval
    public var liveSilenceTimeout: TimeInterval

    public enum Task: String, Sendable {
        case transcribe
        case translate
    }

    public init(
        model: String? = nil,
        modelRepo: String? = nil,
        language: String? = nil,
        task: Task = .transcribe,
        temperature: Float = 0.0,
        wordTimestamps: Bool = false,
        livePartialInterval: TimeInterval = 1.5,
        liveSilenceTimeout: TimeInterval = 1.2
    ) {
        self.model = model
        self.modelRepo = modelRepo
        self.language = language
        self.task = task
        self.temperature = temperature
        self.wordTimestamps = wordTimestamps
        self.livePartialInterval = livePartialInterval
        self.liveSilenceTimeout = liveSilenceTimeout
    }
}

public final class WhisperSpeechToText: @unchecked Sendable, VoiceTranscriber {
    public let config: WhisperConfig
    private let lock = NSLock()
    private var pipeline: WhisperKit?

    #if canImport(AVFoundation) && !os(watchOS)
    private let audioEngine = AVAudioEngine()
    private var liveBuffer: [Float] = []
    private var liveBufferLock = NSLock()
    #endif

    public init(config: WhisperConfig = .init()) {
        self.config = config
    }

    public func preload() async throws {
        _ = try await pipelineOrLoad()
    }

    private func pipelineOrLoad() async throws -> WhisperKit {
        lock.lock()
        if let pipeline { lock.unlock(); return pipeline }
        lock.unlock()
        let cfg = WhisperKitConfig(
            model: config.model,
            modelRepo: config.modelRepo
        )
        let pipe = try await WhisperKit(cfg)
        lock.lock()
        self.pipeline = pipe
        lock.unlock()
        return pipe
    }

    public func requestAuthorization() async -> Bool {
        #if canImport(AVFoundation) && !os(macOS)
        return await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        #else
        return true
        #endif
    }

    public func transcribe(audio: AudioAttachment) async throws -> WhisperTranscription {
        let pipe = try await pipelineOrLoad()
        let path: String
        var cleanup: URL?
        switch audio.source {
        case .fileURL(let url):
            path = url.path
        case .data(let data):
            let ext = Self.fileExtension(for: audio.mimeType)
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + ext)
            try data.write(to: tmp)
            cleanup = tmp
            path = tmp.path
        }
        defer { if let cleanup { try? FileManager.default.removeItem(at: cleanup) } }
        let options = decodingOptions()
        let results = try await pipe.transcribe(audioPath: path, decodeOptions: options)
        return Self.merge(results)
    }

    public func transcribe(samples: [Float]) async throws -> WhisperTranscription {
        let pipe = try await pipelineOrLoad()
        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: decodingOptions())
        return Self.merge(results)
    }

    public func live() throws -> AsyncThrowingStream<VoiceTranscriberResult, Error> {
        #if canImport(AVFoundation) && !os(watchOS)
        return AsyncThrowingStream { continuation in
            let task = _Concurrency.Task { [weak self] in
                guard let self else { continuation.finish(); return }
                do {
                    let pipe = try await self.pipelineOrLoad()
                    try self.startRecording()

                    var lastEmitted = ""
                    var lastChangeAt = Date()
                    let interval = self.config.livePartialInterval
                    let silenceTimeout = self.config.liveSilenceTimeout

                    while !_Concurrency.Task.isCancelled {
                        try await _Concurrency.Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                        let samples = self.snapshotLiveSamples()
                        guard samples.count > 16_000 else { continue }  // need >1 s

                        let results = try? await pipe.transcribe(audioArray: samples, decodeOptions: self.decodingOptions())
                        let merged = results.map(Self.merge) ?? WhisperTranscription(text: "", language: self.config.language ?? "", segments: [])
                        let text = merged.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if text != lastEmitted {
                            lastEmitted = text
                            lastChangeAt = Date()
                            continuation.yield(VoiceTranscriberResult(text: text, isFinal: false))
                        } else if !text.isEmpty, Date().timeIntervalSince(lastChangeAt) >= silenceTimeout {
                            continuation.yield(VoiceTranscriberResult(text: text, isFinal: true))
                            continuation.finish()
                            self.stopRecording()
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.stopRecording()
            }
        }
        #else
        throw AIError.unsupportedCapability("WhisperSpeechToText.live on this platform")
        #endif
    }

    public func stop() {
        #if canImport(AVFoundation) && !os(watchOS)
        stopRecording()
        #endif
    }

    // MARK: - Internals

    private func decodingOptions() -> DecodingOptions {
        DecodingOptions(
            task: config.task == .translate ? .translate : .transcribe,
            language: config.language,
            temperature: config.temperature,
            detectLanguage: config.language == nil,
            wordTimestamps: config.wordTimestamps
        )
    }

    private static func merge(_ results: [TranscriptionResult]) -> WhisperTranscription {
        let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let language = results.first?.language ?? ""
        let segments: [WhisperTranscription.Segment] = results.flatMap { $0.segments }.map {
            .init(text: $0.text, start: $0.start, end: $0.end)
        }
        return WhisperTranscription(text: text, language: language, segments: segments)
    }

    private static func fileExtension(for mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "audio/wav", "audio/x-wav": return "wav"
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/mp4", "audio/m4a", "audio/x-m4a": return "m4a"
        case "audio/flac": return "flac"
        case "audio/ogg": return "ogg"
        default: return "wav"
        }
    }

    #if canImport(AVFoundation) && !os(watchOS)
    private func startRecording() throws {
        liveBufferLock.lock()
        liveBuffer.removeAll(keepingCapacity: true)
        liveBufferLock.unlock()

        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let input = audioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw AIError.unsupportedCapability("16kHz mono Float32 format")
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AIError.unsupportedCapability("AVAudioConverter \(inputFormat) → 16kHz mono")
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let ratio = targetFormat.sampleRate / inputFormat.sampleRate
            let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return }
            var fed = false
            var error: NSError?
            let status = converter.convert(to: outBuffer, error: &error) { _, flag in
                if fed {
                    flag.pointee = .noDataNow
                    return nil
                }
                fed = true
                flag.pointee = .haveData
                return buffer
            }
            guard status != .error, error == nil, let channel = outBuffer.floatChannelData?[0] else { return }
            let frames = Int(outBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channel, count: frames))
            self.liveBufferLock.lock()
            self.liveBuffer.append(contentsOf: samples)
            self.liveBufferLock.unlock()
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func snapshotLiveSamples() -> [Float] {
        liveBufferLock.lock()
        let copy = liveBuffer
        liveBufferLock.unlock()
        return copy
    }
    #endif
}
