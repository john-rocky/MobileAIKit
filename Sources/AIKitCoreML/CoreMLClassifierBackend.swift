import Foundation
import AIKit
import CoreML
import Vision

public struct CoreMLClassification: Sendable, Hashable, Codable {
    public let label: String
    public let confidence: Float
}

public final class CoreMLClassifierTool: @unchecked Sendable {
    public let name: String
    public let model: VNCoreMLModel
    public let inputKey: String

    public init(name: String, model: MLModel, inputKey: String = "image") throws {
        self.name = name
        self.model = try VNCoreMLModel(for: model)
        self.inputKey = inputKey
    }

    public static func load(name: String, at url: URL, computeUnits: MLComputeUnits = .all) throws -> CoreMLClassifierTool {
        let config = MLModelConfiguration()
        config.computeUnits = computeUnits
        let compiled = url.pathExtension == "mlmodelc" ? url : (try MLModel.compileModel(at: url))
        let model = try MLModel(contentsOf: compiled, configuration: config)
        return try CoreMLClassifierTool(name: name, model: model)
    }

    public func classify(imagePath: String, topK: Int = 3) async throws -> [CoreMLClassification] {
        try await classify(imageURL: URL(fileURLWithPath: imagePath), topK: topK)
    }

    public func classify(imageURL: URL, topK: Int = 3) async throws -> [CoreMLClassification] {
        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        let request = VNCoreMLRequest(model: model)
        try handler.perform([request])
        let observations = (request.results as? [VNClassificationObservation]) ?? []
        return observations.prefix(topK).map { .init(label: $0.identifier, confidence: $0.confidence) }
    }

    public func asTool() -> any Tool {
        let toolName = name
        let spec = ToolSpec(
            name: "classify_image_\(name)",
            description: "Run \(name) CoreML classifier on an image file and return top labels.",
            parameters: .object(
                properties: [
                    "file_path": .string(),
                    "top_k": .integer(minimum: 1, maximum: 20)
                ],
                required: ["file_path"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let file_path: String; let top_k: Int? }
        return TypedTool(spec: spec) { (args: Args) async throws -> [CoreMLClassification] in
            _ = toolName
            return try await self.classify(imagePath: args.file_path, topK: args.top_k ?? 3)
        }
    }
}
