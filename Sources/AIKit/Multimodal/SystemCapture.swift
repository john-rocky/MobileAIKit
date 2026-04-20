import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public enum SystemCapture {
    public static func clipboardText() -> String? {
        #if canImport(UIKit)
        return UIPasteboard.general.string
        #elseif canImport(AppKit)
        return NSPasteboard.general.string(forType: .string)
        #else
        return nil
        #endif
    }

    public static func clipboardImage() -> ImageAttachment? {
        #if canImport(UIKit)
        if let image = UIPasteboard.general.image, let data = image.pngData() {
            return ImageAttachment(source: .data(data), width: Int(image.size.width), height: Int(image.size.height), mimeType: "image/png")
        }
        #elseif canImport(AppKit)
        if let ns = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
           let tiff = ns.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            return ImageAttachment(source: .data(data), mimeType: "image/png")
        }
        #endif
        return nil
    }

    #if canImport(UIKit) && os(iOS)
    @MainActor
    public static func screenshot(of window: UIWindow? = nil) -> ImageAttachment? {
        let w = window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first
        guard let w else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: w.bounds)
        let image = renderer.image { context in
            w.layer.render(in: context.cgContext)
        }
        guard let data = image.pngData() else { return nil }
        return ImageAttachment(source: .data(data), width: Int(image.size.width), height: Int(image.size.height), mimeType: "image/png")
    }
    #endif
}
