import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(Speech)
import Speech
#endif
#if canImport(Contacts)
import Contacts
#endif
#if canImport(EventKit)
import EventKit
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif

/// Permissions that the kit can request before running an inference pipeline.
///
/// Used with ``AIKit/withPermissions(_:_:)`` so every vision/voice recipe doesn't
/// hand-roll its own `ensure permission → run model → handle result` shape.
public enum AIPermission: Sendable, Hashable {
    case camera
    case microphone
    case speechRecognition
    case photoLibraryRead
    case photoLibraryAdd
    case contacts
    case calendar
    case reminders
    case locationWhenInUse
}

public extension AIKit {
    /// Run `body` only if every `permission` is granted. Prompts the user for any
    /// permission currently in `.notDetermined`. Throws ``AIError/permissionDenied(_:)``
    /// on the first denial.
    ///
    /// ```swift
    /// let meal = try await AIKit.withPermissions([.camera, .photoLibraryAdd]) {
    ///     try await AIKit.extract(Meal.self, from: image, schema: ..., backend: b)
    /// }
    /// ```
    ///
    /// HealthKit is intentionally excluded — its authorization shape (per-quantity-type
    /// share + read sets) doesn't fit the flat enum. Use ``HealthKitBridge``
    /// (`requestNutritionAuthorization()` etc.) before / inside `body`.
    @discardableResult
    static func withPermissions<T: Sendable>(
        _ permissions: [AIPermission],
        _ body: @Sendable () async throws -> T
    ) async throws -> T {
        for permission in permissions {
            let ok = try await ensure(permission)
            if !ok { throw AIError.permissionDenied(String(describing: permission)) }
        }
        return try await body()
    }

    /// Probe-or-prompt a single permission. Returns `true` if authorized, `false` if denied.
    @discardableResult
    static func ensure(_ permission: AIPermission) async throws -> Bool {
        switch permission {
        case .camera:
            #if canImport(AVFoundation)
            return await ensureAV(.video)
            #else
            return false
            #endif

        case .microphone:
            #if canImport(AVFoundation)
            return await ensureAV(.audio)
            #else
            return false
            #endif

        case .speechRecognition:
            #if canImport(Speech)
            return await ensureSpeech()
            #else
            return false
            #endif

        case .photoLibraryRead:
            #if canImport(Photos)
            return await ensurePhotos(level: .readWrite)
            #else
            return false
            #endif

        case .photoLibraryAdd:
            #if canImport(Photos)
            return await ensurePhotos(level: .addOnly)
            #else
            return false
            #endif

        case .contacts:
            #if canImport(Contacts)
            return try await ensureContacts()
            #else
            return false
            #endif

        case .calendar:
            #if canImport(EventKit)
            return try await ensureEventKit(for: .event)
            #else
            return false
            #endif

        case .reminders:
            #if canImport(EventKit)
            return try await ensureEventKit(for: .reminder)
            #else
            return false
            #endif

        case .locationWhenInUse:
            #if canImport(CoreLocation)
            return await LocationPermissionProbe.shared.requestWhenInUse()
            #else
            return false
            #endif
        }
    }
}

// MARK: - Probes

#if canImport(AVFoundation)
private func ensureAV(_ type: AVMediaType) async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: type) {
    case .authorized: return true
    case .notDetermined: return await AVCaptureDevice.requestAccess(for: type)
    default: return false
    }
}
#endif

#if canImport(Speech)
private func ensureSpeech() async -> Bool {
    let status = SFSpeechRecognizer.authorizationStatus()
    switch status {
    case .authorized: return true
    case .notDetermined:
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { s in cont.resume(returning: s == .authorized) }
        }
    default: return false
    }
}
#endif

#if canImport(Photos)
private func ensurePhotos(level: PHAccessLevel) async -> Bool {
    let status = PHPhotoLibrary.authorizationStatus(for: level)
    switch status {
    case .authorized, .limited: return true
    case .notDetermined:
        let new = await PHPhotoLibrary.requestAuthorization(for: level)
        return new == .authorized || new == .limited
    default: return false
    }
}
#endif

#if canImport(Contacts)
private func ensureContacts() async throws -> Bool {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    if status == .authorized { return true }
    if status != .notDetermined { return false }
    return try await CNContactStore().requestAccess(for: .contacts)
}
#endif

#if canImport(EventKit)
private func ensureEventKit(for entity: EKEntityType) async throws -> Bool {
    let status = EKEventStore.authorizationStatus(for: entity)
    if status == .fullAccess || status == .writeOnly || status == .authorized { return true }
    if status != .notDetermined { return false }
    let store = EKEventStore()
    if entity == .event {
        return try await store.requestFullAccessToEvents()
    } else {
        return try await store.requestFullAccessToReminders()
    }
}
#endif

#if canImport(CoreLocation)
/// CLLocationManager authorization is delegate-based, not async. This probe owns a
/// singleton manager + continuation so callers can `await` the decision.
private final class LocationPermissionProbe: NSObject, @unchecked Sendable, CLLocationManagerDelegate {
    static let shared = LocationPermissionProbe()
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Bool, Never>?
    private let lock = NSLock()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUse() async -> Bool {
        let status = manager.authorizationStatus
        if Self.isAuthorized(status) { return true }
        guard status == .notDetermined else { return false }
        #if os(macOS)
        // macOS CLLocationManager has no "when in use" tier; fall back to the
        // always prompt (delegate still fires on status change).
        return await withCheckedContinuation { cont in
            lock.lock(); continuation = cont; lock.unlock()
            manager.requestAlwaysAuthorization()
        }
        #else
        return await withCheckedContinuation { cont in
            lock.lock(); continuation = cont; lock.unlock()
            manager.requestWhenInUseAuthorization()
        }
        #endif
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: Self.isAuthorized(status))
    }

    private static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        return status == .authorizedAlways
        #else
        return status == .authorizedAlways || status == .authorizedWhenInUse
        #endif
    }
}
#endif
