import Foundation
import AIKit
#if canImport(HealthKit)
import HealthKit
import Observation

/// Observable wrapper around `HKHealthStore` with a baked-in nutrition write path.
///
/// Exposed as `@Observable` so SwiftUI views can react to `isNutritionAuthorized`
/// without maintaining a parallel `@State var healthKitAuthorized: Bool`.
@Observable
public final class HealthKitBridge: @unchecked Sendable {
    public let store = HKHealthStore()

    /// `true` after ``requestNutritionAuthorization()`` returned successfully AND every
    /// quantity type in ``nutritionWriteTypes`` reports `.sharingAuthorized`. iOS never
    /// tells you whether the user granted *read* access — only writes are observable —
    /// so this flag strictly tracks the nutrition write bundle.
    public private(set) var isNutritionAuthorized: Bool = false

    /// `true` once any ``requestAuthorization(share:read:)`` call has returned. Separate
    /// from ``isNutritionAuthorized`` because apps often request read-only scopes first.
    public private(set) var hasRequestedAuthorization: Bool = false

    public init() {
        refreshNutritionAuthorizationFromStore()
    }

    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public func requestReadAccess(for types: Set<HKObjectType>) async throws -> Bool {
        let ok: Bool = try await withCheckedThrowingContinuation { cont in
            store.requestAuthorization(toShare: [], read: types) { success, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: success) }
            }
        }
        hasRequestedAuthorization = true
        return ok
    }

    public func requestAuthorization(
        share: Set<HKSampleType> = [],
        read: Set<HKObjectType> = []
    ) async throws -> Bool {
        let ok: Bool = try await withCheckedThrowingContinuation { cont in
            store.requestAuthorization(toShare: share, read: read) { success, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: success) }
            }
        }
        hasRequestedAuthorization = true
        refreshNutritionAuthorizationFromStore()
        return ok
    }

    /// Re-probe every quantity type in ``nutritionWriteTypes`` via
    /// `authorizationStatus(for:)`. Useful after the app returns from background or
    /// after the user toggles permissions in Settings.
    public func refreshNutritionAuthorizationFromStore() {
        let authorized = Self.nutritionWriteTypes.allSatisfy {
            store.authorizationStatus(for: $0) == .sharingAuthorized
        }
        isNutritionAuthorized = authorized
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

    // MARK: - Nutrition write API

    /// Quantity types that describe a meal entry (dietary energy + macros + water).
    /// Use as the `share` set in ``requestAuthorization(share:read:)``.
    public static var nutritionWriteTypes: Set<HKSampleType> {
        let ids: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietarySugar,
            .dietaryWater
        ]
        return Set(ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    /// Request write authorization for the full nutrition bundle (calories + macros + water).
    /// Updates ``isNutritionAuthorized`` based on the per-type `authorizationStatus` after
    /// the prompt resolves.
    @discardableResult
    public func requestNutritionAuthorization() async throws -> Bool {
        let ok = try await requestAuthorization(share: Self.nutritionWriteTypes)
        refreshNutritionAuthorizationFromStore()
        return ok
    }

    /// Write a nutrition entry to HealthKit. Missing macros are skipped, not zero-written.
    /// - Returns: The `UUID`s of the samples saved (one per present field).
    @discardableResult
    public func saveMeal(_ meal: NutritionEntry, date: Date = Date()) async throws -> [UUID] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AIError.resourceUnavailable("HealthKit not available on this device")
        }
        let metadata: [String: Any] = {
            var m: [String: Any] = [HKMetadataKeyWasUserEntered: true]
            if let name = meal.name { m[HKMetadataKeyFoodType] = name }
            return m
        }()

        var samples: [HKQuantitySample] = []
        func add(_ identifier: HKQuantityTypeIdentifier, _ value: Double?, _ unit: HKUnit) {
            guard let value, value > 0,
                  let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            samples.append(HKQuantitySample(
                type: type, quantity: quantity,
                start: date, end: date, metadata: metadata
            ))
        }

        add(.dietaryEnergyConsumed, meal.calories, .kilocalorie())
        add(.dietaryProtein, meal.proteinGrams, .gram())
        add(.dietaryCarbohydrates, meal.carbohydrateGrams, .gram())
        add(.dietaryFatTotal, meal.fatGrams, .gram())
        add(.dietaryFiber, meal.fiberGrams, .gram())
        add(.dietarySugar, meal.sugarGrams, .gram())
        if let mL = meal.waterMilliliters, mL > 0,
           let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            let q = HKQuantity(unit: .literUnit(with: .milli), doubleValue: mL)
            samples.append(HKQuantitySample(
                type: type, quantity: q,
                start: date, end: date, metadata: metadata
            ))
        }

        guard !samples.isEmpty else { return [] }
        try await store.save(samples)
        return samples.map(\.uuid)
    }

    /// Sum calories + macros over a single day (local calendar).
    public func dailyTotals(
        on day: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> NutritionEntry {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
            return await withCheckedContinuation { cont in
                let q = HKStatisticsQuery(
                    quantityType: type,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, stats, _ in
                    cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
                }
                store.execute(q)
            }
        }

        async let cal = sum(.dietaryEnergyConsumed, unit: .kilocalorie())
        async let pro = sum(.dietaryProtein, unit: .gram())
        async let car = sum(.dietaryCarbohydrates, unit: .gram())
        async let fat = sum(.dietaryFatTotal, unit: .gram())
        async let fib = sum(.dietaryFiber, unit: .gram())
        async let sug = sum(.dietarySugar, unit: .gram())
        async let wat = sum(.dietaryWater, unit: .literUnit(with: .milli))

        return await NutritionEntry(
            name: nil,
            calories: cal,
            proteinGrams: pro,
            carbohydrateGrams: car,
            fatGrams: fat,
            fiberGrams: fib,
            sugarGrams: sug,
            waterMilliliters: wat
        )
    }

    /// Delete samples previously saved by ``saveMeal(_:date:)`` — pass the `UUID`s it returned.
    public func deleteSamples(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        let predicate = HKQuery.predicateForObjects(with: Set(ids))
        let types: [HKQuantityType] = [
            .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates,
            .dietaryFatTotal, .dietaryFiber, .dietarySugar, .dietaryWater
        ].compactMap { HKQuantityType.quantityType(forIdentifier: $0) }

        for type in types {
            _ = try await store.deleteObjects(of: type, predicate: predicate)
        }
    }
}
#endif
