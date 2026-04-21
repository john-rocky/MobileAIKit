import Foundation
import AIKit
#if canImport(LockedCameraCapture) && os(iOS)
import LockedCameraCapture
import SwiftUI

/// Helper for authoring a **Locked Camera Capture Extension** (iOS 18+).
///
/// In your extension target, subclass `LockedCameraCaptureExtension` and forward
/// `invoke(context:)` to ``present(_:for:)`` — this lets you write the captured
/// media to the shared App Group container so your main app can process it
/// through Gemma 4 when unlocked.
@available(iOS 18.0, *)
public enum LockedCameraCaptureBridge {
    /// Persist a captured image to the shared App Group container. Returns the saved URL.
    public static func saveCapturedImage(
        data: Data,
        appGroup: String,
        filename: String = "\(UUID().uuidString).jpg"
    ) throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            throw AIError.resourceUnavailable("App Group \(appGroup) not accessible")
        }
        let captureDir = containerURL.appendingPathComponent("LockedCaptures", isDirectory: true)
        try FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)
        let dest = captureDir.appendingPathComponent(filename)
        try data.write(to: dest, options: .atomic)
        return dest
    }

    /// Lists pending captures saved by the extension, for the main app to consume.
    public static func pendingCaptures(appGroup: String) -> [URL] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return []
        }
        let captureDir = containerURL.appendingPathComponent("LockedCaptures", isDirectory: true)
        return (try? FileManager.default.contentsOfDirectory(at: captureDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    }
}
#endif
