import Foundation
import AIKit
#if canImport(FamilyControls) && os(iOS)
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Minimal wrapper over Apple's Screen Time family of frameworks.
///
/// Requires the **Family Controls** entitlement (`com.apple.developer.family-controls`).
/// Without it, these APIs will throw at runtime. Intended for guardian/focus-style apps.
@available(iOS 16.0, *)
public final class ScreenTimeBridge: @unchecked Sendable {
    public let center = AuthorizationCenter.shared
    public let store = ManagedSettingsStore(named: .default)
    public let monitor = DeviceActivityCenter()

    public init() {}

    public func requestAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
    }

    public func applyShield(to selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }

    public func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    public func startMonitoring(
        name: DeviceActivityName,
        schedule: DeviceActivitySchedule
    ) throws {
        try monitor.startMonitoring(name, during: schedule)
    }

    public func stopMonitoring(_ names: [DeviceActivityName]) {
        monitor.stopMonitoring(names)
    }
}
#endif
