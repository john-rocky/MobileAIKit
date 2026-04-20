import Foundation

public struct AttachmentComposer: Sendable {
    public var maxImagePixels: Int
    public var maxAudioSeconds: Double
    public var maxVideoFrames: Int

    public init(
        maxImagePixels: Int = 1_024 * 1_024,
        maxAudioSeconds: Double = 60,
        maxVideoFrames: Int = 16
    ) {
        self.maxImagePixels = maxImagePixels
        self.maxAudioSeconds = maxAudioSeconds
        self.maxVideoFrames = maxVideoFrames
    }

    public func normalize(_ attachments: [Attachment]) async throws -> [Attachment] {
        var result: [Attachment] = []
        for attachment in attachments {
            switch attachment {
            case .image(let image):
                let normalized = try await image.downsampled(maxPixels: maxImagePixels)
                result.append(.image(normalized))
            case .audio(let audio):
                if let d = audio.durationSeconds, d > maxAudioSeconds {
                    throw AIError.invalidAttachment("Audio exceeds \(maxAudioSeconds) seconds")
                }
                result.append(.audio(audio))
            case .video(let video):
                result.append(.video(video))
            default:
                result.append(attachment)
            }
        }
        return result
    }

    public func describe(_ attachments: [Attachment]) -> String {
        attachments.enumerated().map { idx, att in
            switch att {
            case .image(let i): return "[image \(idx) \(i.mimeType)\(i.caption.map { ": \($0)" } ?? "")]"
            case .audio(let a): return "[audio \(idx) \(a.durationSeconds.map { "\($0)s" } ?? "")]"
            case .video(let v): return "[video \(idx) \(v.durationSeconds.map { "\($0)s" } ?? "")]"
            case .pdf(let p): return "[pdf \(p.fileURL.lastPathComponent)]"
            case .text(let t): return "[text \(t.title ?? "snippet")]"
            case .file(let f): return "[file \(f.fileURL.lastPathComponent)]"
            }
        }.joined(separator: " ")
    }
}
