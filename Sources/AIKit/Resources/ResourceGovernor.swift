import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum DevicePowerMode: String, Sendable, Hashable {
    case normal
    case lowPower
    case thermallyConstrained
    case background
}

public enum QualityProfile: String, Sendable, Hashable, Codable {
    case highQuality
    case balanced
    case fast
    case ultraFast

    public func config(base: GenerationConfig) -> GenerationConfig {
        var c = base
        switch self {
        case .highQuality:
            c.maxTokens = max(base.maxTokens, 1024)
            c.temperature = min(base.temperature, 0.7)
        case .balanced:
            c.maxTokens = min(max(base.maxTokens, 512), 1024)
        case .fast:
            c.maxTokens = min(base.maxTokens, 256)
            c.topK = min(base.topK, 20)
        case .ultraFast:
            c.maxTokens = min(base.maxTokens, 128)
            c.topK = 10
        }
        return c
    }
}

public actor ResourceGovernor {
    public static let shared = ResourceGovernor()

    public private(set) var powerMode: DevicePowerMode = .normal
    public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    public private(set) var isLowPower: Bool = false
    public var preferredProfile: QualityProfile = .balanced
    public var thermalDegradationEnabled: Bool = true

    private var observers: [UUID: @Sendable (DevicePowerMode) -> Void] = [:]

    public init() {
        #if !os(tvOS) && !os(watchOS)
        Task { await self.start() }
        #endif
    }

    public func start() {
        refreshState()
        #if os(iOS) || os(macOS) || os(visionOS) || os(tvOS) || os(watchOS)
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshState() }
        }
        #endif
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshState() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.setBackground(true) }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.setBackground(false) }
        }
        #endif
    }

    public func refreshState() {
        let info = ProcessInfo.processInfo
        thermalState = info.thermalState
        isLowPower = info.isLowPowerModeEnabled
        let newMode: DevicePowerMode
        switch (thermalState, isLowPower) {
        case (.critical, _), (.serious, _):
            newMode = .thermallyConstrained
        case (_, true):
            newMode = .lowPower
        default:
            newMode = .normal
        }
        if newMode != powerMode {
            powerMode = newMode
            notify()
        }
    }

    private func setBackground(_ inBackground: Bool) {
        if inBackground {
            powerMode = .background
        } else {
            refreshState()
        }
        notify()
    }

    private func notify() {
        let mode = powerMode
        for (_, cb) in observers { cb(mode) }
    }

    public func observe(_ callback: @Sendable @escaping (DevicePowerMode) -> Void) -> UUID {
        let id = UUID()
        observers[id] = callback
        callback(powerMode)
        return id
    }

    public func stopObserving(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    public func recommendedProfile() -> QualityProfile {
        if !thermalDegradationEnabled { return preferredProfile }
        switch powerMode {
        case .thermallyConstrained: return .ultraFast
        case .lowPower: return .fast
        case .background: return .fast
        case .normal: return preferredProfile
        }
    }

    public func guardedConfig(base: GenerationConfig) -> GenerationConfig {
        recommendedProfile().config(base: base)
    }

    public func availableMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let physicalTotal = ProcessInfo.processInfo.physicalMemory
        return physicalTotal > info.resident_size ? physicalTotal - info.resident_size : 0
    }

    public func deviceClass() -> DeviceClass {
        let ram = ProcessInfo.processInfo.physicalMemory
        if ram >= 7_000_000_000 { return .highTier }
        if ram >= 5_000_000_000 { return .midTier }
        if ram >= 3_000_000_000 { return .lowTier }
        return .constrained
    }
}

public enum DeviceClass: String, Sendable, Hashable, Codable {
    case highTier
    case midTier
    case lowTier
    case constrained
}
