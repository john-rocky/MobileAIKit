import SwiftUI
import AIKit
#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIKit
#endif
#if canImport(VisionKit) && os(iOS)
import VisionKit
#endif
#if canImport(MapKit)
import MapKit
#endif

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)

// MARK: - Camera

@available(iOS 17.0, visionOS 1.0, *)
struct AgentCameraPicker: UIViewControllerRepresentable {
    let options: CameraOptions
    let onFinish: (ImageAttachment?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = options.preferredCamera == .front ? .front : .rear
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = options.allowsEditing
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (ImageAttachment?) -> Void
        init(onFinish: @escaping (ImageAttachment?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let image, let data = image.jpegData(compressionQuality: 0.85) {
                onFinish(ImageAttachment(
                    source: .data(data),
                    width: Int(image.size.width),
                    height: Int(image.size.height),
                    mimeType: "image/jpeg"
                ))
            } else {
                onFinish(nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
    }
}

// MARK: - Document scanner

@available(iOS 17.0, visionOS 1.0, *)
struct AgentDocumentScanner: UIViewControllerRepresentable {
    let onFinish: ([ImageAttachment]?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    #if canImport(VisionKit) && os(iOS)
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}
    #else
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async { onFinish(nil) }
        return vc
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
    #endif

    final class Coordinator: NSObject {
        let onFinish: ([ImageAttachment]?) -> Void
        init(onFinish: @escaping ([ImageAttachment]?) -> Void) { self.onFinish = onFinish }
    }
}

#if canImport(VisionKit) && os(iOS)
@available(iOS 17.0, *)
extension AgentDocumentScanner.Coordinator: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var attachments: [ImageAttachment] = []
        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            if let data = image.jpegData(compressionQuality: 0.85) {
                attachments.append(ImageAttachment(
                    source: .data(data),
                    width: Int(image.size.width),
                    height: Int(image.size.height),
                    mimeType: "image/jpeg"
                ))
            }
        }
        onFinish(attachments)
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onFinish(nil) }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onFinish(nil) }
}
#endif

// MARK: - Live text / barcode scanner

#if canImport(VisionKit) && os(iOS)
@available(iOS 17.0, *)
struct AgentLiveScanner: UIViewControllerRepresentable {
    let options: TextScannerOptions
    let onFinish: ([String]?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        var types: Set<DataScannerViewController.RecognizedDataType> = []
        if options.types.contains(.text) { types.insert(.text()) }
        if options.types.contains(.barcode) { types.insert(.barcode()) }
        if options.types.contains(.qr) { types.insert(.barcode(symbologies: [.qr])) }
        if types.isEmpty { types.insert(.text()) }
        let vc = DataScannerViewController(
            recognizedDataTypes: types,
            qualityLevel: .balanced,
            recognizesMultipleItems: options.recognizeMultiple,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            try? controller.startScanning()
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFinish: ([String]?) -> Void
        private var buffer: [String] = []
        init(onFinish: @escaping ([String]?) -> Void) { self.onFinish = onFinish }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text): buffer.append(text.transcript); onFinish(buffer)
            case .barcode(let b): buffer.append(b.payloadStringValue ?? ""); onFinish(buffer)
            @unknown default: break
            }
        }
    }
}
#endif

// MARK: - Share sheet

@available(iOS 17.0, visionOS 1.0, *)
struct AgentShareSheet: UIViewControllerRepresentable {
    let items: [ShareItem]
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var activityItems: [Any] = []
        for item in items {
            switch item {
            case .text(let t): activityItems.append(t)
            case .url(let u): activityItems.append(u)
            case .file(let u): activityItems.append(u)
            case .image(let img):
                switch img.source {
                case .data(let d):
                    if let ui = UIImage(data: d) { activityItems.append(ui) }
                case .fileURL(let url): activityItems.append(url)
                case .url(let url): activityItems.append(url)
                }
            }
        }
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed)
        }
        return vc
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Location picker

@available(iOS 17.0, visionOS 1.0, *)
struct AgentLocationPicker: View {
    let options: LocationPickerOptions
    let onFinish: (PickedLocation?) -> Void

    @State private var position: MapCameraPosition
    @State private var pinned: CLLocationCoordinate2D?
    @State private var name: String = ""

    init(options: LocationPickerOptions, onFinish: @escaping (PickedLocation?) -> Void) {
        self.options = options
        self.onFinish = onFinish
        let initial = CLLocationCoordinate2D(
            latitude: options.initialLatitude ?? 35.681236,
            longitude: options.initialLongitude ?? 139.767125
        )
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: initial,
            latitudinalMeters: 2000, longitudinalMeters: 2000
        )))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $position) {
                        if let pin = pinned {
                            Marker("Selected", coordinate: pin)
                        }
                    }
                    .onTapGesture { screenPoint in
                        if let coord = proxy.convert(screenPoint, from: .local) {
                            pinned = coord
                        }
                    }
                }
                if pinned != nil {
                    TextField("Name (optional)", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                }
            }
            .navigationTitle("Pick a location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onFinish(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let p = pinned {
                            onFinish(PickedLocation(
                                latitude: p.latitude,
                                longitude: p.longitude,
                                name: name.isEmpty ? nil : name
                            ))
                        } else {
                            onFinish(nil)
                        }
                    }
                    .disabled(pinned == nil)
                }
            }
        }
    }
}

#endif
