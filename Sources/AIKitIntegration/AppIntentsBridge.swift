import Foundation
import AIKit
#if canImport(AppIntents)
import AppIntents
#endif

#if canImport(AppIntents)
@available(iOS 17.0, macOS 14.0, *)
public struct AIKitChatIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ask MobileAIKit"

    @Parameter(title: "Prompt")
    public var prompt: String

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let backend = Self.backendProvider?() else {
            return .result(value: "Backend not configured.")
        }
        let answer = try await AIKit.chat(prompt, backend: backend)
        return .result(value: answer)
    }

    public static var backendProvider: (@Sendable () -> (any AIBackend)?)?
}

@available(iOS 17.0, macOS 14.0, *)
public struct AIKitShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AIKitChatIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) \(\.$prompt)"
            ],
            shortTitle: "Ask AI",
            systemImageName: "bubble.left.and.bubble.right"
        )
    }
}
#endif
