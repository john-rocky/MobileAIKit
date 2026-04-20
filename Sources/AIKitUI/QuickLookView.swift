import SwiftUI
#if canImport(QuickLook)
import QuickLook
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(QuickLook) && canImport(UIKit)
@available(iOS 17.0, visionOS 1.0, *)
public struct AIQuickLookView: UIViewControllerRepresentable {
    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func makeCoordinator() -> Coordinator { Coordinator(fileURL: fileURL) }

    public func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    public func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    public final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        init(fileURL: URL) { self.fileURL = fileURL }
        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            fileURL as NSURL
        }
    }
}
#endif
