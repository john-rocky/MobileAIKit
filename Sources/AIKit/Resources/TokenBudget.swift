import Foundation

public struct TokenBudget: Sendable, Hashable {
    public var total: Int
    public var reservedForSystem: Int
    public var reservedForOutput: Int

    public init(total: Int, reservedForSystem: Int = 200, reservedForOutput: Int = 512) {
        self.total = total
        self.reservedForSystem = reservedForSystem
        self.reservedForOutput = reservedForOutput
    }

    public var availableForInput: Int {
        max(0, total - reservedForSystem - reservedForOutput)
    }
}

public struct TokenBudgetPlanner: Sendable {
    public var backend: any AIBackend
    public var budget: TokenBudget

    public init(backend: any AIBackend, budget: TokenBudget? = nil) {
        self.backend = backend
        self.budget = budget ?? TokenBudget(total: backend.info.contextLength)
    }

    public func truncate(messages: [Message]) async throws -> [Message] {
        var working = messages
        let cap = budget.availableForInput
        while try await backend.tokenCount(for: working) > cap {
            guard let dropIndex = firstDroppable(in: working) else { break }
            working.remove(at: dropIndex)
        }
        return working
    }

    public func split(messages: [Message], into maxBatches: Int) async throws -> [[Message]] {
        let cap = budget.availableForInput
        var batches: [[Message]] = []
        var current: [Message] = []
        for m in messages {
            current.append(m)
            let count = try await backend.tokenCount(for: current)
            if count > cap {
                current.removeLast()
                if !current.isEmpty { batches.append(current) }
                current = [m]
                if batches.count >= maxBatches { break }
            }
        }
        if !current.isEmpty { batches.append(current) }
        return batches
    }

    private func firstDroppable(in messages: [Message]) -> Int? {
        for (i, m) in messages.enumerated() {
            if m.role == .user || m.role == .assistant { return i }
        }
        return nil
    }
}

public enum BatteryBudget {
    public static func current() -> Double {
        #if canImport(UIKit) && os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = Double(UIDevice.current.batteryLevel)
        return level >= 0 ? level : 1.0
        #else
        return 1.0
        #endif
    }

    public static func recommendedProfile() -> QualityProfile {
        let level = current()
        if level < 0.15 { return .ultraFast }
        if level < 0.30 { return .fast }
        if level < 0.50 { return .balanced }
        return .highQuality
    }
}

#if canImport(UIKit) && os(iOS)
import UIKit
#endif
