import Foundation
import AIKit

public enum VisionTools {
    public static func ocrTool() -> any Tool {
        let spec = ToolSpec(
            name: "ocr_image",
            description: "Extract text from an image file on disk. Returns the full detected text.",
            parameters: .object(
                properties: [
                    "file_path": .string(description: "Absolute path to the image file."),
                    "languages": .array(items: .string(), description: "Language codes.")
                ],
                required: ["file_path"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let file_path: String; let languages: [String]? }
        struct Out: Encodable { let text: String; let regionCount: Int }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let url = URL(fileURLWithPath: args.file_path)
            let att = ImageAttachment(source: .fileURL(url))
            let result = try await OCR.recognize(in: att, languages: args.languages ?? ["en-US"])
            return Out(text: result.text, regionCount: result.regions.count)
        }
    }

    public static func imageAnalysisTool() -> any Tool {
        let spec = ToolSpec(
            name: "analyze_image",
            description: "Analyze an image: detect faces, rectangles, barcodes.",
            parameters: .object(
                properties: ["file_path": .string()],
                required: ["file_path"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let file_path: String }
        return TypedTool(spec: spec) { (args: Args) async throws -> ImageAnalysisResult in
            let url = URL(fileURLWithPath: args.file_path)
            return try await ImageAnalysis.analyze(ImageAttachment(source: .fileURL(url)))
        }
    }
}
