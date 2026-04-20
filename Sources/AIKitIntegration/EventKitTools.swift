import Foundation
import AIKit
#if canImport(EventKit)
import EventKit
#endif

#if canImport(EventKit)
public final class EventKitBridge: @unchecked Sendable {
    public let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await store.requestAccess(to: .event)
        }
    }

    public func createEventTool() -> any Tool {
        let spec = ToolSpec(
            name: "create_calendar_event",
            description: "Create a new calendar event.",
            parameters: .object(
                properties: [
                    "title": .string(),
                    "start": .string(format: "date-time"),
                    "end": .string(format: "date-time"),
                    "location": .string(),
                    "notes": .string()
                ],
                required: ["title", "start", "end"]
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        struct Args: Decodable {
            let title: String
            let start: String
            let end: String
            let location: String?
            let notes: String?
        }
        struct Out: Encodable { let eventId: String }
        return TypedTool(spec: spec) { [store] (args: Args) async throws -> Out in
            let event = EKEvent(eventStore: store)
            event.title = args.title
            event.startDate = try Self.parseDate(args.start)
            event.endDate = try Self.parseDate(args.end)
            event.location = args.location
            event.notes = args.notes
            event.calendar = store.defaultCalendarForNewEvents
            try store.save(event, span: .thisEvent)
            return Out(eventId: event.eventIdentifier ?? "")
        }
    }

    public func listEventsTool() -> any Tool {
        let spec = ToolSpec(
            name: "list_calendar_events",
            description: "List upcoming events in a date range.",
            parameters: .object(
                properties: [
                    "start": .string(format: "date-time"),
                    "end": .string(format: "date-time")
                ],
                required: ["start", "end"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let start: String; let end: String }
        struct EventOut: Encodable {
            let id: String; let title: String; let start: String; let end: String
            let location: String?
        }
        return TypedTool(spec: spec) { [store] (args: Args) async throws -> [EventOut] in
            let start = try Self.parseDate(args.start)
            let end = try Self.parseDate(args.end)
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            return store.events(matching: predicate).map { ev in
                EventOut(
                    id: ev.eventIdentifier ?? "",
                    title: ev.title ?? "",
                    start: ISO8601DateFormatter().string(from: ev.startDate),
                    end: ISO8601DateFormatter().string(from: ev.endDate),
                    location: ev.location
                )
            }
        }
    }

    static func parseDate(_ s: String) throws -> Date {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current
        if let d = formatter.date(from: s) { return d }
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let d = formatter.date(from: s) { return d }
        throw AIError.toolArgumentsInvalid(tool: "calendar", reason: "Invalid date '\(s)'")
    }
}
#endif
