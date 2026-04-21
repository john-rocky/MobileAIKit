import SwiftUI
import AIKit
import AIKitUI
import AIKitIntegration
import AIKitVision
import AIKitSpeech

/// True one-liner agent surface: drop this in a SwiftUI hierarchy and the user
/// can chat with a model that can drive the camera, calendar, contacts,
/// maps, health, weather, web, vision, and speech — whatever the current
/// platform can provide.
///
/// ```swift
/// struct ContentView: View {
///     let backend: any AIBackend
///     var body: some View {
///         AIAgentDefaultView(backend: backend)
///     }
/// }
/// ```
///
/// Customise by passing ``AgentKit/BuildOptions`` or by appending
/// developer-owned tools via `extraTools:`.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
@MainActor
public struct AIAgentDefaultView: View {
    public let backend: any AIBackend
    public let options: AgentKit.BuildOptions
    public let extraTools: [any Tool]

    @State private var agent: AIAgent?

    public init(
        backend: any AIBackend,
        options: AgentKit.BuildOptions = .default,
        extraTools: [any Tool] = []
    ) {
        self.backend = backend
        self.options = options
        self.extraTools = extraTools
    }

    public var body: some View {
        Group {
            if let agent {
                AIAgentView(agent: agent, additionalTools: extraTools)
            } else {
                ProgressView("Preparing assistant…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: ObjectIdentifier(backend)) {
            if agent != nil { return }
            agent = await AgentKit.build(backend: backend, options: options)
        }
    }
}
