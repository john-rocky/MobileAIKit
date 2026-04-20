import Foundation
import AIKit
#if canImport(CoreMotion)
import CoreMotion

public final class MotionBridge: @unchecked Sendable {
    private let manager = CMMotionManager()
    private let pedometer = CMPedometer()

    public init() {}

    public func currentAttitude() async throws -> (pitch: Double, roll: Double, yaw: Double) {
        guard manager.isDeviceMotionAvailable else {
            throw AIError.unsupportedCapability("CoreMotion deviceMotion")
        }
        manager.deviceMotionUpdateInterval = 0.1
        return try await withCheckedThrowingContinuation { cont in
            manager.startDeviceMotionUpdates(to: .main) { motion, error in
                if let error { cont.resume(throwing: error); self.manager.stopDeviceMotionUpdates(); return }
                guard let motion else { return }
                let a = motion.attitude
                cont.resume(returning: (a.pitch, a.roll, a.yaw))
                self.manager.stopDeviceMotionUpdates()
            }
        }
    }

    public func stepCountTool() -> any Tool {
        let spec = ToolSpec(
            name: "motion_step_count",
            description: "Return step count for the last N hours via CoreMotion pedometer.",
            parameters: .object(
                properties: ["hours": .number(minimum: 0.1, maximum: 168)],
                required: ["hours"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let hours: Double }
        struct Out: Encodable { let steps: Int; let distanceMeters: Double }
        return TypedTool(spec: spec) { [pedometer] (args: Args) async throws -> Out in
            let end = Date()
            let start = end.addingTimeInterval(-args.hours * 3600)
            return try await withCheckedThrowingContinuation { cont in
                pedometer.queryPedometerData(from: start, to: end) { data, error in
                    if let error { cont.resume(throwing: error); return }
                    let steps = data?.numberOfSteps.intValue ?? 0
                    let meters = data?.distance?.doubleValue ?? 0
                    cont.resume(returning: Out(steps: steps, distanceMeters: meters))
                }
            }
        }
    }
}
#endif
