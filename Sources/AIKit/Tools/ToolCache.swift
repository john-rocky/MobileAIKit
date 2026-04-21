import Foundation

public actor ToolResultCache {
    public struct Entry: Sendable {
        public let result: ToolResult
        public let insertedAt: Date
    }

    public var capacity: Int
    public var defaultTTL: TimeInterval
    private var store: [String: Entry] = [:]
    private var order: [String] = []

    public init(capacity: Int = 256, defaultTTL: TimeInterval = 300) {
        self.capacity = capacity
        self.defaultTTL = defaultTTL
    }

    public func get(key: String) -> ToolResult? {
        guard let entry = store[key] else { return nil }
        if Date().timeIntervalSince(entry.insertedAt) > defaultTTL {
            store.removeValue(forKey: key)
            order.removeAll { $0 == key }
            return nil
        }
        return entry.result
    }

    public func put(key: String, value: ToolResult) {
        store[key] = Entry(result: value, insertedAt: Date())
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > capacity {
            let removed = order.removeFirst()
            store.removeValue(forKey: removed)
        }
    }

    public func clear() {
        store.removeAll(); order.removeAll()
    }

    public static func key(toolName: String, arguments: String) -> String {
        "\(toolName)|\(arguments)"
    }
}

public actor ToolRetry {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval

    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 0.5, maxDelay: TimeInterval = 10) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    public func run<T: Sendable>(_ op: @Sendable () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do { return try await op() }
            catch {
                lastError = error
                if attempt == maxAttempts - 1 { break }
                let delay = min(maxDelay, baseDelay * pow(2.0, Double(attempt))) + Double.random(in: 0...0.1)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? AIError.unknown("retry exhausted")
    }
}
