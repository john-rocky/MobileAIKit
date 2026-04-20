import Foundation
import AIKit
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreImage)
import CoreImage
#endif

public struct OCRResult: Sendable, Hashable, Codable {
    public struct Region: Sendable, Hashable, Codable {
        public let text: String
        public let confidence: Float
        public let boundingBox: CGRect
    }
    public let text: String
    public let regions: [Region]

    public init(text: String, regions: [Region]) {
        self.text = text
        self.regions = regions
    }
}

public enum OCR {
    public static func recognize(
        in attachment: ImageAttachment,
        languages: [String] = ["en-US", "ja-JP"],
        fastPass: Bool = false
    ) async throws -> OCRResult {
        #if canImport(Vision) && canImport(CoreImage)
        let data = try await attachment.loadData()
        guard let cg = try Self.cgImage(from: data) else {
            throw AIError.invalidAttachment("Unable to decode image for OCR")
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = fastPass ? .fast : .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try handler.perform([request])
        let observations = (request.results ?? [])
        var regions: [OCRResult.Region] = []
        var fullText = ""
        for obs in observations {
            guard let top = obs.topCandidates(1).first else { continue }
            regions.append(.init(text: top.string, confidence: top.confidence, boundingBox: obs.boundingBox))
            if !fullText.isEmpty { fullText += "\n" }
            fullText += top.string
        }
        return OCRResult(text: fullText, regions: regions)
        #else
        throw AIError.unsupportedCapability("OCR requires Vision framework")
        #endif
    }

    #if canImport(CoreImage)
    static func cgImage(from data: Data) throws -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    #endif
}
