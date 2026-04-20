import Foundation
import AIKit
#if canImport(CoreHaptics) && os(iOS)
import CoreHaptics

public final class HapticsBridge: @unchecked Sendable {
    public private(set) var engine: CHHapticEngine?

    public init() {}

    public func start() throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            throw AIError.unsupportedCapability("Haptics")
        }
        let e = try CHHapticEngine()
        try e.start()
        self.engine = e
    }

    public func pulse(intensity: Float = 1.0, sharpness: Float = 0.5) throws {
        guard let engine else { throw AIError.resourceUnavailable("Haptics engine") }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makePlayer(with: pattern)
        try player.start(atTime: 0)
    }
}
#endif
