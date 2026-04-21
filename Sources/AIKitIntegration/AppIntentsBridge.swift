import Foundation
import AIKit
#if canImport(AppIntents)
import AppIntents
#endif

#if canImport(AppIntents)
@available(iOS 17.0, macOS 14.0, *)
public struct AIKitChatIntent: AppIntent {
    public static let title: LocalizedStringResource = "Ask LocalAIKit"

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

    /// Host apps set this once during launch to provide the backend used by
    /// Shortcuts invocations. nonisolated(unsafe) because AppIntent can't host
    /// this as an actor-isolated value and consumers set it before any shortcut
    /// runs.
    public nonisolated(unsafe) static var backendProvider: (@Sendable () -> (any AIBackend)?)?
}

@available(iOS 17.0, macOS 14.0, *)
public struct AIKitShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        // Natural-language parameter injection (`\(\.$prompt)`) requires
        // `prompt` to be an AppEntity or AppEnum; plain `String` isn't
        // allowed anymore. Shortcuts can still trigger the intent and
        // prompt the user for input via the standard picker.
        AppShortcut(
            intent: AIKitChatIntent(),
            phrases: [
                "Ask \(.applicationName)"
            ],
            shortTitle: "Ask AI",
            systemImageName: "bubble.left.and.bubble.right"
        )
    }
}
#endif
