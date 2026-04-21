import SwiftUI
import AIKit
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit

/// Full-screen camera preview with a big shutter. Sister of ``AICameraAssistantView``
/// for food-tracking / scan-first apps where picking from a PhotosPicker is two taps
/// too many. `onCapture` fires once the user taps the shutter.
///
/// ```swift
/// AICameraCaptureView { image in
///     Task { let nutrition = try await AIKit.extract(...) }
/// }
/// ```
///
/// Remember to set `NSCameraUsageDescription` in the consumer app's Info.plist.
@available(iOS 17.0, *)
public struct AICameraCaptureView: View {
    public var onCapture: (UIImage) -> Void
    public var onCancel: (() -> Void)?
    public var shutterDiameter: CGFloat
    public var overlay: AnyView?

    @State private var model = CameraModel()
    @State private var error: String?

    public init(
        shutterDiameter: CGFloat = 78,
        overlay: AnyView? = nil,
        onCancel: (() -> Void)? = nil,
        onCapture: @escaping (UIImage) -> Void
    ) {
        self.shutterDiameter = shutterDiameter
        self.overlay = overlay
        self.onCancel = onCancel
        self.onCapture = onCapture
    }

    public var body: some View {
        ZStack {
            CameraPreview(session: model.session)
                .ignoresSafeArea()

            if let overlay { overlay }

            VStack {
                HStack {
                    if let onCancel {
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Circle().fill(.black.opacity(0.35)))
                        }
                        .padding()
                    }
                    Spacer()
                    Button {
                        model.toggleCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(.black.opacity(0.35)))
                    }
                    .padding()
                }
                Spacer()
                Button {
                    model.capture { image in
                        guard let image else { return }
                        Task { @MainActor in onCapture(image) }
                    }
                } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: shutterDiameter, height: shutterDiameter)
                        .overlay(
                            Circle()
                                .fill(.white)
                                .padding(6)
                        )
                }
                .padding(.bottom, 32)
                .accessibilityLabel("Capture photo")
            }

            if let error {
                VStack {
                    Spacer()
                    Text(error)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Capsule().fill(.red.opacity(0.85)))
                        .padding(.bottom, 140)
                }
            }
        }
        .task {
            do { try await model.start() } catch { self.error = error.localizedDescription }
        }
        .onDisappear { model.stop() }
    }
}

// MARK: - Internals

@available(iOS 17.0, *)
final class CameraModel: @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private let queue = DispatchQueue(label: "aikit.camera.session")
    private var delegates: [PhotoCaptureDelegate] = []

    func start() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw AIError.permissionDenied("Camera access denied") }
        } else if status != .authorized {
            throw AIError.permissionDenied("Camera access denied")
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                session.beginConfiguration()
                if session.canSetSessionPreset(.photo) {
                    session.sessionPreset = .photo
                }
                do {
                    try attachDevice(position: .back)
                    if session.canAddOutput(output) { session.addOutput(output) }
                    session.commitConfiguration()
                    session.startRunning()
                    cont.resume()
                } catch {
                    session.commitConfiguration()
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func toggleCamera() {
        queue.async { [self] in
            guard let current = currentInput else { return }
            let newPos: AVCaptureDevice.Position = current.device.position == .back ? .front : .back
            session.beginConfiguration()
            session.removeInput(current)
            currentInput = nil
            try? attachDevice(position: newPos)
            session.commitConfiguration()
        }
    }

    func capture(completion: @escaping @Sendable (UIImage?) -> Void) {
        queue.async { [self] in
            let settings = AVCapturePhotoSettings()
            let delegate = PhotoCaptureDelegate { [weak self] image in
                completion(image)
                guard let self else { return }
                self.queue.async {
                    self.delegates.removeAll { ObjectIdentifier($0) == ObjectIdentifier(delegate) }
                }
            }
            delegates.append(delegate)
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func attachDevice(position: AVCaptureDevice.Position) throws {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualWideCamera, .builtInTripleCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first else {
            throw AIError.resourceUnavailable("No camera for position \(position.rawValue)")
        }
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        } else {
            throw AIError.resourceUnavailable("Cannot add camera input")
        }
    }
}

@available(iOS 17.0, *)
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let handler: @Sendable (UIImage?) -> Void
    init(handler: @escaping @Sendable (UIImage?) -> Void) { self.handler = handler }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        handler(image)
    }
}

@available(iOS 17.0, *)
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
#endif
