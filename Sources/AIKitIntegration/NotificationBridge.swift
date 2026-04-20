import Foundation
import AIKit
#if canImport(UserNotifications)
import UserNotifications

public enum NotificationBridge {
    public static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    public static func schedule(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        after seconds: TimeInterval
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    public static func scheduleTool() -> any Tool {
        let spec = ToolSpec(
            name: "schedule_notification",
            description: "Schedule a local notification to fire after N seconds.",
            parameters: .object(
                properties: [
                    "title": .string(),
                    "body": .string(),
                    "after_seconds": .number(minimum: 1)
                ],
                required: ["title", "body", "after_seconds"]
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        struct Args: Decodable { let title: String; let body: String; let after_seconds: Double }
        struct Out: Encodable { let id: String }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let id = UUID().uuidString
            try await schedule(id: id, title: args.title, body: args.body, after: args.after_seconds)
            return Out(id: id)
        }
    }
}
#endif
