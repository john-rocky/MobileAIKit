import Foundation
import AIKit
#if canImport(ActivityKit) && os(iOS)
@preconcurrency import ActivityKit

public struct GenerationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var status: String
        public var tokens: Int
        public var tokensPerSecond: Double

        public init(status: String, tokens: Int = 0, tokensPerSecond: Double = 0) {
            self.status = status
            self.tokens = tokens
            self.tokensPerSecond = tokensPerSecond
        }
    }

    public let backendName: String
    public let prompt: String

    public init(backendName: String, prompt: String) {
        self.backendName = backendName
        self.prompt = prompt
    }
}

@available(iOS 16.1, *)
public actor GenerationActivityController {
    private var activity: Activity<GenerationActivityAttributes>?

    public init() {}

    public func start(backendName: String, prompt: String) throws {
        guard activity == nil else { return }
        let attr = GenerationActivityAttributes(backendName: backendName, prompt: prompt)
        let state = GenerationActivityAttributes.ContentState(status: "Thinking…")
        self.activity = try Activity.request(
            attributes: attr,
            content: .init(state: state, staleDate: Date().addingTimeInterval(300))
        )
    }

    public func update(status: String, tokens: Int, tokensPerSecond: Double) async {
        let newState = GenerationActivityAttributes.ContentState(
            status: status, tokens: tokens, tokensPerSecond: tokensPerSecond
        )
        await activity?.update(ActivityContent(state: newState, staleDate: Date().addingTimeInterval(300)))
    }

    public func end(final status: String = "Done") async {
        let newState = GenerationActivityAttributes.ContentState(status: status)
        await activity?.end(
            ActivityContent(state: newState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        activity = nil
    }
}
#endif
