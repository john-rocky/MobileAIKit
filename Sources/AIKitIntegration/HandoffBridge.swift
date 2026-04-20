import Foundation
import AIKit
#if canImport(UIKit) && os(iOS)
import UIKit
#endif

#if canImport(UIKit) && os(iOS)
@MainActor
public final class HandoffBridge: @unchecked Sendable {
    private var activity: NSUserActivity?

    public init() {}

    public func publish(activityType: String, title: String, info: [String: Any]) {
        let a = NSUserActivity(activityType: activityType)
        a.title = title
        a.userInfo = info
        a.isEligibleForHandoff = true
        a.isEligibleForSearch = true
        a.isEligibleForPublicIndexing = false
        a.becomeCurrent()
        self.activity = a
    }

    public func invalidate() {
        activity?.invalidate()
        activity = nil
    }
}
#endif
