import Foundation
import AIKit
#if canImport(ScreenCaptureKit) && os(macOS)
import ScreenCaptureKit
import CoreGraphics
import ImageIO

@available(macOS 14.0, *)
public enum ScreenCaptureKitBridge {
    public static func captureMainDisplay() async throws -> ImageAttachment {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw AIError.resourceUnavailable("No display available")
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return ImageAttachment(image)
    }

    public static func captureScreenTool() -> any Tool {
        let spec = ToolSpec(
            name: "capture_screen",
            description: "Take a screenshot of the main display (macOS).",
            parameters: .object(properties: [:], required: []),
            requiresApproval: true,
            sideEffectFree: true
        )
        struct Args: Decodable {}
        struct Out: Encodable { let width: Int; let height: Int; let base64PNG: String }
        return TypedTool(spec: spec) { (_: Args) async throws -> Out in
            let attachment = try await captureMainDisplay()
            let data = try await attachment.loadData()
            return Out(
                width: attachment.width ?? 0,
                height: attachment.height ?? 0,
                base64PNG: data.base64EncodedString()
            )
        }
    }
}
#endif
