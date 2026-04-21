import Foundation
import AIKit
import AIKitIntegration
import AIKitVision
import AIKitSpeech

/// One-stop façade that wires a fully-loaded ``AIAgent`` with every available
/// tool pack (integration, vision, speech) plus the UI-presenting host tools.
public enum AgentKit {
    /// Options for ``AgentKit/build(backend:host:options:)``.
    public struct BuildOptions: Sendable {
        public var systemPrompt: String?
        public var integration: IntegrationToolPackOptions
        public var includeVisionTools: Bool
        public var includeSpeechTools: Bool
        public var includeHostTools: Bool
        public var agentOptions: AIAgentOptions

        public init(
            systemPrompt: String? = nil,
            integration: IntegrationToolPackOptions = .default,
            includeVisionTools: Bool = true,
            includeSpeechTools: Bool = true,
            includeHostTools: Bool = true,
            agentOptions: AIAgentOptions = .default
        ) {
            self.systemPrompt = systemPrompt
            self.integration = integration
            self.includeVisionTools = includeVisionTools
            self.includeSpeechTools = includeSpeechTools
            self.includeHostTools = includeHostTools
            self.agentOptions = agentOptions
        }

        public static let `default` = BuildOptions()
    }

    /// Build an ``AIAgent`` pre-loaded with every tool this platform supports.
    ///
    /// ```swift
    /// let agent = await AgentKit.build(backend: backend)   // headless
    /// // or
    /// AIAgentView(agent: agent)                            // view-attached
    /// ```
    @MainActor
    public static func build(
        backend: any AIBackend,
        host: any AgentHost = NullAgentHost(),
        options: BuildOptions = .default
    ) async -> AIAgent {
        let agent = AIAgent(
            backend: backend,
            host: host,
            systemPrompt: options.systemPrompt,
            tools: [],
            options: options.agentOptions
        )
        if options.includeHostTools { await agent.registerHostTools() }
        await agent.registerIntegrationTools(options: options.integration)
        if options.includeVisionTools { await agent.registerVisionTools() }
        if options.includeSpeechTools { await agent.registerSpeechTools() }
        return agent
    }
}
