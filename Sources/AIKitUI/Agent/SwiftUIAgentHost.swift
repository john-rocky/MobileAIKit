import SwiftUI
import AIKit
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(VisionKit) && os(iOS)
import VisionKit
#endif
#if canImport(MapKit)
import MapKit
#endif

/// ``AgentHost`` implementation driven by SwiftUI state.
///
/// `AIAgentView` creates one of these internally and installs it as
/// ``AIAgent/host``. Developers rarely interact with it directly, but the
/// class is public so custom chrome (navigation, toolbars) can embed the
/// agent's sheets on its own terms.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
@MainActor
@Observable
public final class SwiftUIAgentHost: AgentHost {
    // Pending request types — rendered as sheets / full-screen covers by AIAgentView.
    public enum PendingRequest: Identifiable {
        case camera(CameraOptions, CheckedContinuation<ImageAttachment, Error>)
        case photoPicker(PhotoPickerOptions, CheckedContinuation<[ImageAttachment], Error>)
        case documentScanner(CheckedContinuation<[ImageAttachment], Error>)
        case textScanner(TextScannerOptions, CheckedContinuation<[String], Error>)
        case locationPicker(LocationPickerOptions, CheckedContinuation<PickedLocation, Error>)
        case filePicker(FilePickerOptions, CheckedContinuation<[URL], Error>)
        case share([ShareItem], CheckedContinuation<Void, Error>)
        case confirm(ConfirmRequest)

        public var id: String {
            switch self {
            case .camera: return "camera"
            case .photoPicker: return "photoPicker"
            case .documentScanner: return "documentScanner"
            case .textScanner: return "textScanner"
            case .locationPicker: return "locationPicker"
            case .filePicker: return "filePicker"
            case .share: return "share"
            case .confirm(let r): return "confirm-\(r.id)"
            }
        }
    }

    public struct ConfirmRequest: Identifiable {
        public let id = UUID()
        public let title: String
        public let message: String?
        public let isDestructive: Bool
        let continuation: CheckedContinuation<Bool, Never>
    }

    public private(set) var pending: PendingRequest?
    public private(set) var status: String?

    public init() {}

    // MARK: - AgentHost

    public func presentCamera(options: CameraOptions) async throws -> ImageAttachment {
        try await withCheckedThrowingContinuation { cont in
            pending = .camera(options, cont)
        }
    }

    public func presentPhotoPicker(options: PhotoPickerOptions) async throws -> [ImageAttachment] {
        try await withCheckedThrowingContinuation { cont in
            pending = .photoPicker(options, cont)
        }
    }

    public func presentDocumentScanner() async throws -> [ImageAttachment] {
        try await withCheckedThrowingContinuation { cont in
            pending = .documentScanner(cont)
        }
    }

    public func presentTextScanner(options: TextScannerOptions) async throws -> [String] {
        try await withCheckedThrowingContinuation { cont in
            pending = .textScanner(options, cont)
        }
    }

    public func presentLocationPicker(options: LocationPickerOptions) async throws -> PickedLocation {
        try await withCheckedThrowingContinuation { cont in
            pending = .locationPicker(options, cont)
        }
    }

    public func presentFilePicker(options: FilePickerOptions) async throws -> [URL] {
        try await withCheckedThrowingContinuation { cont in
            pending = .filePicker(options, cont)
        }
    }

    public func presentShareSheet(items: [ShareItem]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pending = .share(items, cont)
        }
    }

    public func confirm(title: String, message: String?, isDestructive: Bool) async -> Bool {
        await withCheckedContinuation { cont in
            pending = .confirm(ConfirmRequest(
                title: title, message: message,
                isDestructive: isDestructive,
                continuation: cont
            ))
        }
    }

    public func openURL(_ url: URL) async throws {
        #if canImport(UIKit) && !os(watchOS)
        await UIApplication.shared.open(url)
        #else
        throw AgentHostError.unavailable("openURL is only supported on iOS/visionOS")
        #endif
    }

    public func showStatus(_ text: String) {
        status = text
        let target = text
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                if self.status == target { self.status = nil }
            }
        }
    }

    // MARK: - Resolution helpers (called from sheets)

    public func clearPending() { pending = nil }

    public func resolveCamera(with image: ImageAttachment?) {
        guard case let .camera(_, cont) = pending else { return }
        if let image { cont.resume(returning: image) }
        else { cont.resume(throwing: AgentHostError.cancelled) }
        pending = nil
    }

    public func resolvePhotos(with images: [ImageAttachment]) {
        guard case let .photoPicker(_, cont) = pending else { return }
        if images.isEmpty { cont.resume(throwing: AgentHostError.cancelled) }
        else { cont.resume(returning: images) }
        pending = nil
    }

    public func resolveDocumentScanner(with images: [ImageAttachment]?) {
        guard case let .documentScanner(cont) = pending else { return }
        if let images, !images.isEmpty { cont.resume(returning: images) }
        else { cont.resume(throwing: AgentHostError.cancelled) }
        pending = nil
    }

    public func resolveTextScanner(with values: [String]?) {
        guard case let .textScanner(_, cont) = pending else { return }
        if let values, !values.isEmpty { cont.resume(returning: values) }
        else { cont.resume(throwing: AgentHostError.cancelled) }
        pending = nil
    }

    public func resolveLocation(with loc: PickedLocation?) {
        guard case let .locationPicker(_, cont) = pending else { return }
        if let loc { cont.resume(returning: loc) }
        else { cont.resume(throwing: AgentHostError.cancelled) }
        pending = nil
    }

    public func resolveFiles(with urls: [URL]?) {
        guard case let .filePicker(_, cont) = pending else { return }
        if let urls, !urls.isEmpty { cont.resume(returning: urls) }
        else { cont.resume(throwing: AgentHostError.cancelled) }
        pending = nil
    }

    public func resolveShare(succeeded: Bool) {
        guard case let .share(_, cont) = pending else { return }
        if succeeded { cont.resume(returning: ()) }
        else { cont.resume(throwing: AgentHostError.cancelled) }
        pending = nil
    }

    public func resolveConfirm(_ value: Bool) {
        guard case let .confirm(req) = pending else { return }
        req.continuation.resume(returning: value)
        pending = nil
    }

    public func cancelPending() {
        guard let p = pending else { return }
        switch p {
        case .camera(_, let c): c.resume(throwing: AgentHostError.cancelled)
        case .photoPicker(_, let c): c.resume(throwing: AgentHostError.cancelled)
        case .documentScanner(let c): c.resume(throwing: AgentHostError.cancelled)
        case .textScanner(_, let c): c.resume(throwing: AgentHostError.cancelled)
        case .locationPicker(_, let c): c.resume(throwing: AgentHostError.cancelled)
        case .filePicker(_, let c): c.resume(throwing: AgentHostError.cancelled)
        case .share(_, let c): c.resume(throwing: AgentHostError.cancelled)
        case .confirm(let r): r.continuation.resume(returning: false)
        }
        pending = nil
    }
}
