import Foundation
import AIKit
#if canImport(BackgroundTasks) && os(iOS)
@preconcurrency import BackgroundTasks

public enum BackgroundTaskRegistrar {
    public static func registerPrewarm(identifier: String, action: @Sendable @escaping () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            let op = Task {
                await action()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { op.cancel() }
        }
    }

    public static func schedulePrewarm(identifier: String, earliestBeginDate: Date = Date().addingTimeInterval(15 * 60)) throws {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        try BGTaskScheduler.shared.submit(request)
    }

    public static func scheduleProcessing(
        identifier: String,
        earliestBeginDate: Date = Date().addingTimeInterval(60 * 60),
        requiresNetworkConnectivity: Bool = true,
        requiresExternalPower: Bool = false
    ) throws {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        request.requiresNetworkConnectivity = requiresNetworkConnectivity
        request.requiresExternalPower = requiresExternalPower
        try BGTaskScheduler.shared.submit(request)
    }
}
#endif
