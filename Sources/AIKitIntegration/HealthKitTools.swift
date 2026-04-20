import Foundation
import AIKit
#if canImport(HealthKit)
import HealthKit

public final class HealthKitBridge: @unchecked Sendable {
    public let store = HKHealthStore()

    public init() {}

    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public func requestReadAccess(for types: Set<HKObjectType>) async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            store.requestAuthorization(toShare: [], read: types) { success, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: success) }
            }
        }
    }

    public func recentStepCountTool() -> any Tool {
        let spec = ToolSpec(
            name: "health_step_count",
            description: "Return the user's step count for the last N days.",
            parameters: .object(
                properties: ["days": .integer(minimum: 1, maximum: 60)],
                required: ["days"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let days: Int }
        struct Out: Encodable { let totalSteps: Double; let dailyAverage: Double }
        return TypedTool(spec: spec) { [store] (args: Args) async throws -> Out in
            guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
                throw AIError.unsupportedCapability("HealthKit stepCount")
            }
            let end = Date()
            let start = Calendar.current.date(byAdding: .day, value: -args.days, to: end) ?? end
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let total: Double = try await withCheckedThrowingContinuation { cont in
                let query = HKStatisticsQuery(
                    quantityType: type,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, stats, error in
                    if let error { cont.resume(throwing: error); return }
                    let sum = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    cont.resume(returning: sum)
                }
                store.execute(query)
            }
            return Out(totalSteps: total, dailyAverage: total / Double(args.days))
        }
    }
}
#endif
