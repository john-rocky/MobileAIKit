import Foundation
import AIKit
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

#if canImport(WidgetKit)
public enum WidgetRefresh {
    public static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    public static func reload(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
#endif

#if canImport(ActivityKit) && os(iOS)
public enum LiveActivity {
    @available(iOS 16.1, *)
    public static func start<Attributes: ActivityAttributes>(
        attributes: Attributes,
        state: Attributes.ContentState,
        staleAfter: TimeInterval = 3600
    ) throws -> Activity<Attributes> {
        try Activity<Attributes>.request(
            attributes: attributes,
            content: .init(state: state, staleDate: Date().addingTimeInterval(staleAfter)),
            pushType: nil
        )
    }

    @available(iOS 16.2, *)
    public static func update<Attributes: ActivityAttributes>(
        activity: Activity<Attributes>,
        state: Attributes.ContentState,
        staleAfter: TimeInterval = 3600
    ) async {
        await activity.update(
            ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleAfter))
        )
    }

    @available(iOS 16.2, *)
    public static func end<Attributes: ActivityAttributes>(_ activity: Activity<Attributes>) async {
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
#endif
