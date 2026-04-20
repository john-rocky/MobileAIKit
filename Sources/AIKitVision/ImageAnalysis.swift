import Foundation
import AIKit
#if canImport(Vision)
import Vision
#endif

public struct ImageAnalysisResult: Sendable, Hashable, Codable {
    public struct DetectedObject: Sendable, Hashable, Codable {
        public let label: String
        public let confidence: Float
        public let boundingBox: CGRect
    }
    public struct Face: Sendable, Hashable, Codable {
        public let boundingBox: CGRect
        public let roll: Float?
        public let yaw: Float?
    }
    public var objects: [DetectedObject]
    public var faces: [Face]
    public var horizonAngle: Float?
    public var dominantColors: [String]
    public var barcodes: [String]

    public init(
        objects: [DetectedObject] = [],
        faces: [Face] = [],
        horizonAngle: Float? = nil,
        dominantColors: [String] = [],
        barcodes: [String] = []
    ) {
        self.objects = objects
        self.faces = faces
        self.horizonAngle = horizonAngle
        self.dominantColors = dominantColors
        self.barcodes = barcodes
    }
}

public enum ImageAnalysis {
    public static func analyze(_ attachment: ImageAttachment) async throws -> ImageAnalysisResult {
        #if canImport(Vision)
        let data = try await attachment.loadData()
        guard let cg = try OCR.cgImage(from: data) else {
            throw AIError.invalidAttachment("Unable to decode image")
        }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let faceRequest = VNDetectFaceRectanglesRequest()
        let horizonRequest = VNDetectHorizonRequest()
        let barcodeRequest = VNDetectBarcodesRequest()
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.maximumObservations = 20

        try handler.perform([faceRequest, horizonRequest, barcodeRequest, rectangleRequest])

        var result = ImageAnalysisResult()
        for obs in faceRequest.results ?? [] {
            result.faces.append(.init(boundingBox: obs.boundingBox, roll: obs.roll?.floatValue, yaw: obs.yaw?.floatValue))
        }
        if let h = horizonRequest.results?.first {
            result.horizonAngle = h.angle
        }
        for obs in barcodeRequest.results ?? [] {
            if let payload = obs.payloadStringValue {
                result.barcodes.append(payload)
            }
        }
        for obs in rectangleRequest.results ?? [] {
            result.objects.append(.init(label: "rectangle", confidence: obs.confidence, boundingBox: obs.boundingBox))
        }
        return result
        #else
        throw AIError.unsupportedCapability("Image analysis requires Vision")
        #endif
    }
}
