import Foundation
import os

public struct TelemetrySpan: Sendable {
    public let name: String
    public let start: Date
    private let finish: @Sendable (TelemetrySpan) -> Void

    init(name: String, finish: @Sendable @escaping (TelemetrySpan) -> Void) {
        self.name = name
        self.start = Date()
        self.finish = finish
    }

    public func end() { finish(self) }
    public var elapsed: TimeInterval { Date().timeIntervalSince(start) }
}

public struct TelemetryEvent: Sendable, Codable, Hashable {
    public let timestamp: Date
    public let name: String
    public let duration: TimeInterval?
    public let metadata: [String: String]

    public init(timestamp: Date = Date(), name: String, duration: TimeInterval? = nil, metadata: [String: String] = [:]) {
        self.timestamp = timestamp
        self.name = name
        self.duration = duration
        self.metadata = metadata
    }
}

public actor Telemetry {
    public var events: [TelemetryEvent] = []
    public var maxEvents: Int
    public var logger: Logger?
    public var localOnly: Bool
    public var privacyRedactor: (@Sendable (String) -> String)?

    public init(
        maxEvents: Int = 1000,
        logger: Logger? = Logger(subsystem: "LocalAIKit", category: "Telemetry"),
        localOnly: Bool = true,
        privacyRedactor: (@Sendable (String) -> String)? = nil
    ) {
        self.maxEvents = maxEvents
        self.logger = logger
        self.localOnly = localOnly
        self.privacyRedactor = privacyRedactor
    }

    public nonisolated func beginSpan(_ name: String) -> TelemetrySpan {
        TelemetrySpan(name: name) { span in
            Task { await self.recordSpan(span) }
        }
    }

    private func recordSpan(_ span: TelemetrySpan) {
        let event = TelemetryEvent(
            name: span.name,
            duration: span.elapsed,
            metadata: [:]
        )
        push(event)
    }

    public func record(event: TelemetryEvent) {
        push(event)
    }

    public func record(usage: GenerationUsage) {
        push(TelemetryEvent(
            name: "generation.usage",
            metadata: [
                "promptTokens": String(usage.promptTokens),
                "completionTokens": String(usage.completionTokens),
                "prefillSeconds": String(format: "%.4f", usage.prefillTimeSeconds),
                "decodeSeconds": String(format: "%.4f", usage.decodeTimeSeconds),
                "tokensPerSecond": String(format: "%.2f", usage.tokensPerSecond)
            ]
        ))
    }

    public func export() -> [TelemetryEvent] { events }

    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(events)
    }

    public func clear() { events.removeAll() }

    private func push(_ event: TelemetryEvent) {
        var e = event
        if let redactor = privacyRedactor {
            var newMeta: [String: String] = [:]
            for (k, v) in e.metadata { newMeta[k] = redactor(v) }
            e = TelemetryEvent(timestamp: e.timestamp, name: e.name, duration: e.duration, metadata: newMeta)
        }
        events.append(e)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        logger?.debug("event \(e.name, privacy: .public) duration=\(e.duration ?? 0)")
    }
}
