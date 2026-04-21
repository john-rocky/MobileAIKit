import Foundation
import AIKit
#if canImport(AudioToolbox) && canImport(AVFoundation)
import AudioToolbox
import AVFoundation

public enum AudioToolboxBridge {
    /// Convert any Apple-supported audio file to 16-bit PCM WAV — useful before feeding audio to Gemma 4 or SFSpeechRecognizer file recognition.
    public static func convertToWav(
        source: URL,
        destination: URL? = nil,
        sampleRate: Double = 16_000,
        channels: Int = 1
    ) throws -> URL {
        let out = destination ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")

        let srcFile = try AVAudioFile(forReading: source)
        guard let destFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: true
        ) else {
            throw AIError.invalidAttachment("Unable to build destination format")
        }

        var settings = destFormat.settings
        settings[AVFormatIDKey] = kAudioFormatLinearPCM
        let destFile = try AVAudioFile(forWriting: out, settings: settings)

        guard let converter = AVAudioConverter(from: srcFile.processingFormat, to: destFormat) else {
            throw AIError.invalidAttachment("Could not create converter")
        }

        let bufferFrames: AVAudioFrameCount = 4096
        let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFile.processingFormat, frameCapacity: bufferFrames)!
        let destBuffer = AVAudioPCMBuffer(pcmFormat: destFormat, frameCapacity: AVAudioFrameCount(Double(bufferFrames) * sampleRate / srcFile.processingFormat.sampleRate))!

        while srcFile.framePosition < srcFile.length {
            try srcFile.read(into: srcBuffer)
            if srcBuffer.frameLength == 0 { break }

            var error: NSError?
            _ = converter.convert(to: destBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return srcBuffer
            }
            if let error { throw error }
            try destFile.write(from: destBuffer)
        }

        return out
    }

    /// Load a WAV file as `[Float]` — format expected by many on-device audio models.
    public static func loadPCMFloats(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw AIError.invalidAttachment("Could not allocate buffer")
        }
        try file.read(into: buffer)
        guard let channelData = buffer.floatChannelData else {
            throw AIError.invalidAttachment("No float channel data")
        }
        let frameCount = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
    }
}
#endif
