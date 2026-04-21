import Foundation
import AIKit

@MainActor
public extension AIAgent {
    /// Register OCR + image analysis tools. Operate on `file_path` arguments, so
    /// pair with the built-in `take_photo`/`pick_photos` tools which return file
    /// paths in their results.
    func registerVisionTools() async {
        await addTools([
            VisionTools.ocrTool(),
            VisionTools.imageAnalysisTool()
        ])
    }
}
