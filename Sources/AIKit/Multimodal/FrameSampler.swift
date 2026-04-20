import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(UIKit)
import UIKit
#endif

public struct FrameSampler: Sendable {
    public var maxFrames: Int
    public var maxPixels: Int

    public init(maxFrames: Int = 12, maxPixels: Int = 512 * 512) {
        self.maxFrames = maxFrames
        self.maxPixels = maxPixels
    }

    #if canImport(AVFoundation)
    public func sample(videoURL: URL) async throws -> [ImageAttachment] {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        guard totalSeconds > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let count = maxFrames
        var result: [ImageAttachment] = []
        for i in 0..<count {
            let time = CMTime(seconds: totalSeconds * Double(i) / Double(count), preferredTimescale: 600)
            do {
                let (cg, _) = try await Self.image(from: generator, at: time)
                if let att = try encode(cg: cg) { result.append(att) }
            } catch { continue }
        }
        return result
    }

    #if compiler(>=5.9)
    private static func image(from generator: AVAssetImageGenerator, at time: CMTime) async throws -> (CGImage, CMTime) {
        try await withCheckedThrowingContinuation { cont in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, actualTime, result, error in
                switch result {
                case .succeeded:
                    if let image { cont.resume(returning: (image, actualTime)) }
                    else { cont.resume(throwing: AIError.invalidAttachment("null frame")) }
                case .failed:
                    cont.resume(throwing: error ?? AIError.invalidAttachment("frame failed"))
                case .cancelled:
                    cont.resume(throwing: AIError.cancelled)
                @unknown default:
                    cont.resume(throwing: AIError.unknown("generate frame"))
                }
            }
        }
    }
    #endif

    private func encode(cg: CGImage) throws -> ImageAttachment? {
        let pixels = cg.width * cg.height
        let scale = pixels > maxPixels ? (Double(maxPixels) / Double(pixels)).squareRoot() : 1.0
        let w = Int(Double(cg.width) * scale)
        let h = Int(Double(cg.height) * scale)
        #if canImport(CoreImage) && canImport(UIKit)
        let ci = CIImage(cgImage: cg)
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ctx = CIContext()
        guard let output = ctx.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: w, height: h)) else {
            return nil
        }
        let ui = UIImage(cgImage: output)
        guard let data = ui.pngData() else { return nil }
        return ImageAttachment(source: .data(data), width: w, height: h, mimeType: "image/png")
        #else
        return nil
        #endif
    }
    #endif
}
