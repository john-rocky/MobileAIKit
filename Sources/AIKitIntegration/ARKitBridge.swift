import Foundation
import AIKit
#if canImport(ARKit) && os(iOS)
import ARKit

// Not @MainActor: ARSession invokes its delegate on an internal queue,
// so the delegate method must be callable off the main actor. Internal
// state is guarded by a lock so `frames()` (any caller) and the ARKit
// callback thread can safely read/write the continuation.
public final class ARKitBridge: NSObject, @unchecked Sendable, ARSessionDelegate {
    public let session = ARSession()
    private let lock = NSLock()
    private var frameContinuation: AsyncStream<ARFrame>.Continuation?

    public override init() {
        super.init()
        session.delegate = self
    }

    public static var isSupported: Bool { ARWorldTrackingConfiguration.isSupported }

    public func start(configuration: ARConfiguration? = nil) {
        let cfg = configuration ?? ARWorldTrackingConfiguration()
        session.run(cfg)
    }

    public func stop() { session.pause() }

    /// Captures a single image from the current AR camera feed.
    public func captureCurrentFrame() async -> ImageAttachment? {
        guard let frame = session.currentFrame else { return nil }
        let pixelBuffer = frame.capturedImage
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return ImageAttachment(cg)
    }

    /// Live-frame stream for continuous ML pipelines.
    public func frames() -> AsyncStream<ARFrame> {
        AsyncStream { continuation in
            lock.withLock { frameContinuation = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.frameContinuation = nil }
            }
        }
    }

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let cont = lock.withLock { frameContinuation }
        cont?.yield(frame)
    }
}
#endif
