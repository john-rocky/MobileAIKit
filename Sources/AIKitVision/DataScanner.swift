import Foundation
import AIKit
#if canImport(VisionKit) && os(iOS)
import VisionKit
import SwiftUI
import UIKit

@available(iOS 16.0, *)
public struct AIDataScannerView: UIViewControllerRepresentable {
    public let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    public let onScan: (String) -> Void

    public init(
        recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [.text()],
        onScan: @escaping (String) -> Void
    ) {
        self.recognizedDataTypes = recognizedDataTypes
        self.onScan = onScan
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    public func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    public func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            try? controller.startScanning()
        }
    }

    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text): onScan(text.transcript)
            case .barcode(let barcode): onScan(barcode.payloadStringValue ?? "")
            @unknown default: break
            }
        }

        public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                switch item {
                case .text(let text): onScan(text.transcript)
                case .barcode(let b): onScan(b.payloadStringValue ?? "")
                @unknown default: break
                }
            }
        }
    }
}
#endif
