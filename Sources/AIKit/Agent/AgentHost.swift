import Foundation

/// A platform-neutral contract for presenting UI on behalf of an ``AIAgent``.
///
/// Agent tools that must show a sheet, picker, camera, map, or confirmation dialog
/// route through an `AgentHost` instead of calling UIKit / AppKit directly.
///
/// - `AIAgentView` installs itself as the host automatically.
/// - `NullAgentHost` is used when an agent is created without a UI context
///   (background task, Siri shortcut, test). It throws ``AgentHostError/noHost``
///   from every UI-presenting method so the model sees an explicit failure and
///   can fall back to another approach (e.g. "please attach a photo instead").
///
/// Custom hosts (AppKit, UIKit, RealityKit) can conform to this protocol to
/// bridge the agent into a non-standard presentation stack.
@MainActor
public protocol AgentHost: AnyObject, Sendable {
    /// Presents the system camera and returns the captured photo.
    func presentCamera(options: CameraOptions) async throws -> ImageAttachment

    /// Presents the Photos picker (or file importer on non-iOS) and returns chosen images.
    func presentPhotoPicker(options: PhotoPickerOptions) async throws -> [ImageAttachment]

    /// Presents `VNDocumentCameraViewController` and returns one page per scanned image.
    func presentDocumentScanner() async throws -> [ImageAttachment]

    /// Presents `DataScannerViewController` for text / barcode scanning.
    func presentTextScanner(options: TextScannerOptions) async throws -> [String]

    /// Presents a map-based location picker and returns the chosen coordinate.
    func presentLocationPicker(options: LocationPickerOptions) async throws -> PickedLocation

    /// Presents a file importer and returns the picked file URLs.
    func presentFilePicker(options: FilePickerOptions) async throws -> [URL]

    /// Presents the system share sheet for the given items.
    func presentShareSheet(items: [ShareItem]) async throws

    /// Presents a yes/no confirmation dialog. Used for destructive / approval-required tools.
    func confirm(title: String, message: String?, isDestructive: Bool) async -> Bool

    /// Opens a URL via the system (Safari, Maps, deep link, etc.).
    func openURL(_ url: URL) async throws

    /// Shows a non-blocking transient status indicator (toast / HUD).
    func showStatus(_ text: String)
}

public struct CameraOptions: Sendable, Hashable, Codable {
    public enum Camera: String, Sendable, Hashable, Codable { case rear, front }
    public var preferredCamera: Camera
    public var allowsEditing: Bool
    public init(preferredCamera: Camera = .rear, allowsEditing: Bool = false) {
        self.preferredCamera = preferredCamera
        self.allowsEditing = allowsEditing
    }
    public static let `default` = CameraOptions()
}

public struct PhotoPickerOptions: Sendable, Hashable, Codable {
    public var maxCount: Int
    public init(maxCount: Int = 1) { self.maxCount = maxCount }
    public static let `default` = PhotoPickerOptions()
}

public struct TextScannerOptions: Sendable, Hashable, Codable {
    public enum ScanType: String, Sendable, Hashable, Codable { case text, barcode, qr }
    public var types: Set<ScanType>
    public var recognizeMultiple: Bool
    public init(types: Set<ScanType> = [.text], recognizeMultiple: Bool = true) {
        self.types = types
        self.recognizeMultiple = recognizeMultiple
    }
    public static let `default` = TextScannerOptions()
}

public struct LocationPickerOptions: Sendable, Hashable, Codable {
    public var initialLatitude: Double?
    public var initialLongitude: Double?
    public init(initialLatitude: Double? = nil, initialLongitude: Double? = nil) {
        self.initialLatitude = initialLatitude
        self.initialLongitude = initialLongitude
    }
    public static let `default` = LocationPickerOptions()
}

public struct PickedLocation: Sendable, Hashable, Codable {
    public let latitude: Double
    public let longitude: Double
    public let name: String?
    public init(latitude: Double, longitude: Double, name: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
    }
}

public struct FilePickerOptions: Sendable, Hashable, Codable {
    public var allowsMultiple: Bool
    public var contentTypeIdentifiers: [String]
    public init(allowsMultiple: Bool = false, contentTypeIdentifiers: [String] = []) {
        self.allowsMultiple = allowsMultiple
        self.contentTypeIdentifiers = contentTypeIdentifiers
    }
    public static let `default` = FilePickerOptions()
}

public enum ShareItem: Sendable, Hashable {
    case text(String)
    case url(URL)
    case file(URL)
    case image(ImageAttachment)
}

public enum AgentHostError: LocalizedError, Sendable {
    case noHost
    case cancelled
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .noHost:
            return "No UI host is attached. Present the agent inside an AIAgentView, or set agent.host before calling UI-presenting tools."
        case .cancelled:
            return "The user cancelled the requested action."
        case .unavailable(let reason):
            return reason
        }
    }
}

/// Default `AgentHost` that refuses every UI request.
///
/// Used when an agent is constructed without a view layer (background tasks, Siri
/// shortcuts, unit tests). UI-requiring tools throw ``AgentHostError/noHost`` so
/// the language model can observe the failure and pick a non-UI strategy.
@MainActor
public final class NullAgentHost: AgentHost {
    public init() {}

    public func presentCamera(options: CameraOptions) async throws -> ImageAttachment {
        throw AgentHostError.noHost
    }
    public func presentPhotoPicker(options: PhotoPickerOptions) async throws -> [ImageAttachment] {
        throw AgentHostError.noHost
    }
    public func presentDocumentScanner() async throws -> [ImageAttachment] {
        throw AgentHostError.noHost
    }
    public func presentTextScanner(options: TextScannerOptions) async throws -> [String] {
        throw AgentHostError.noHost
    }
    public func presentLocationPicker(options: LocationPickerOptions) async throws -> PickedLocation {
        throw AgentHostError.noHost
    }
    public func presentFilePicker(options: FilePickerOptions) async throws -> [URL] {
        throw AgentHostError.noHost
    }
    public func presentShareSheet(items: [ShareItem]) async throws {
        throw AgentHostError.noHost
    }
    public func confirm(title: String, message: String?, isDestructive: Bool) async -> Bool {
        false
    }
    public func openURL(_ url: URL) async throws {
        throw AgentHostError.noHost
    }
    public func showStatus(_ text: String) {}
}
