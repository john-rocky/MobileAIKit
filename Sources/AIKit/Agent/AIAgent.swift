import Foundation

/// A drop-in, general-purpose AI agent for your app.
///
/// Give `AIAgent` an ``AIBackend`` and (optionally) an ``AgentHost``, and the
/// model can drive everything registered on its ``ToolRegistry`` — camera,
/// calendar, contacts, maps, HealthKit, web search, your own `@AITool`s…
///
/// Two integration modes:
///
/// ```swift
/// // 1. View-attached — best for in-app chat surfaces.
/// //    AIAgentView installs itself as AgentHost automatically.
/// AIAgentView(backend: backend)
///
/// // 2. Headless — background tasks, Siri shortcuts, tests.
/// let agent = AIAgent(backend: backend)
/// let reply = try await agent.send("Summarize today's calendar.")
/// ```
///
/// `AIAgent` is built on top of ``ChatSession`` so memory, retrieval, telemetry,
/// and streaming all work out of the box. Tools that require the host throw
/// ``AgentHostError/noHost`` when no host is attached; the model receives the
/// error and can retry with a different strategy.
@MainActor
@Observable
public final class AIAgent {
    public let backend: any AIBackend
    public let registry: ToolRegistry
    public let session: ChatSession

    /// UI host used by tools that need to present a picker, camera, sheet, etc.
    public var host: any AgentHost {
        didSet { bindApprovalHandler() }
    }

    public var options: AIAgentOptions {
        didSet { applyOptions() }
    }

    public var messages: [Message] { session.messages }
    public var isGenerating: Bool { session.isGenerating }
    public var lastError: AIError? { session.lastError }

    public var systemPrompt: String? {
        get { session.systemPrompt }
        set { session.systemPrompt = newValue }
    }

    public init(
        backend: any AIBackend,
        host: any AgentHost = NullAgentHost(),
        systemPrompt: String? = nil,
        tools: [any Tool] = [],
        config: GenerationConfig = .default,
        options: AIAgentOptions = .default
    ) {
        self.backend = backend
        self.host = host
        self.options = options

        let registry = ToolRegistry()
        self.registry = registry

        let effectivePrompt = systemPrompt ?? AIAgent.defaultSystemPrompt
        self.session = ChatSession(
            backend: backend,
            systemPrompt: effectivePrompt,
            config: config,
            toolRegistry: registry
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            for tool in tools {
                await self.registry.register(tool)
            }
            await self.refreshToolSpecs()
            await self.bindApprovalHandlerAsync()
            await self.applyOptionsAsync()
        }
    }

    /// Registers an additional tool. Safe to call at any time.
    public func addTool(_ tool: any Tool) async {
        await registry.register(tool)
        await refreshToolSpecs()
    }

    public func addTools(_ tools: [any Tool]) async {
        for tool in tools { await registry.register(tool) }
        await refreshToolSpecs()
    }

    public func removeTool(named name: String) async {
        await registry.unregister(name)
        await refreshToolSpecs()
    }

    /// Registers every built-in host-presenting tool (camera, pickers, scanner,
    /// location picker, share sheet, open URL). Safe to call multiple times.
    public func registerHostTools() async {
        let provider = hostProvider()
        let backendRef = backend
        let backendProvider: @Sendable () async -> any AIBackend = { backendRef }
        var tools = AgentTools.all(hostProvider: provider)
        tools.append(AgentTools.describeImageTool(backendProvider: backendProvider))
        await addTools(tools)
    }

    /// A closure that resolves the current ``AgentHost`` on demand.
    ///
    /// Use when building custom tools that need UI presentation — the closure
    /// always returns the agent's *current* host, so reassigning ``host`` at
    /// runtime is safe.
    public func hostProvider() -> AgentHostProvider {
        return { [weak self] in
            guard let self else { return NullAgentHost() }
            return await MainActor.run { self.host }
        }
    }

    /// Send a user message and run the tool-calling loop to completion.
    @discardableResult
    public func send(_ text: String, attachments: [Attachment] = []) async throws -> Message {
        try await session.send(text, attachments: attachments)
    }

    /// Send a user message and stream assistant deltas as tokens arrive.
    public func sendStream(_ text: String, attachments: [Attachment] = []) -> AsyncThrowingStream<GenerationChunk, Error> {
        session.sendStream(text, attachments: attachments)
    }

    /// Cancel the in-flight generation, if any.
    public func cancel() { session.cancel() }

    /// Clear chat history (keeps the system prompt by default).
    public func reset(keepSystem: Bool = true) { session.clear(keepSystem: keepSystem) }

    /// Snapshot of the current conversation for persistence / undo.
    public func snapshot() -> ConversationSnapshot { session.snapshot() }

    /// Restore a previously captured snapshot.
    public func restore(_ snapshot: ConversationSnapshot) { session.restore(snapshot) }

    // MARK: - Internals

    private func refreshToolSpecs() async {
        let specs = await registry.specs()
        session.tools = specs
    }

    private func bindApprovalHandler() {
        Task { await bindApprovalHandlerAsync() }
    }

    private func bindApprovalHandlerAsync() async {
        let handler: @Sendable (ToolSpec, Data) async -> Bool = { [weak self] spec, args in
            guard let self else { return false }
            return await self.handleApproval(spec: spec, argumentsData: args)
        }
        await registry.setApprovalHandler(handler)
    }

    private func handleApproval(spec: ToolSpec, argumentsData: Data) async -> Bool {
        if options.autoApproveReadOnly && spec.sideEffectFree { return true }
        let argString = String(data: argumentsData, encoding: .utf8) ?? ""
        let message: String
        if argString.isEmpty || argString == "{}" {
            message = spec.description
        } else {
            message = "\(spec.description)\n\nArguments: \(argString)"
        }
        return await host.confirm(
            title: "Allow \(spec.name)?",
            message: message,
            isDestructive: !spec.sideEffectFree
        )
    }

    private func applyOptions() {
        Task { await applyOptionsAsync() }
    }

    private func applyOptionsAsync() async {
        var config = session.config
        config.maxTokens = options.maxTokens
        session.config = config
    }

    /// Default system prompt used when the caller doesn't supply one.
    public static var defaultSystemPrompt: String {
        """
        You are an on-device AI assistant embedded in the user's app. You have access to tools \
        that can read the user's data (calendar, contacts, health, photos, location, weather), \
        open the camera or pickers, search the web, and perform app-specific actions registered \
        by the developer.

        Rules:
        1. Prefer tools when fresh data or user context is needed.
        2. Call at most one tool per turn unless tools can run in parallel without side effects.
        3. If a UI-presenting tool fails with "no UI host", explain to the user what they can do \
           instead (e.g. attach a file manually).
        4. For destructive or privacy-sensitive actions, trust the approval dialog to gate the call \
           — don't ask the user separately.
        5. Keep answers short and to the point unless the user asks for detail.
        """
    }
}

public struct AIAgentOptions: Sendable, Hashable, Codable {
    /// When true, side-effect-free tools that otherwise require approval are auto-approved.
    /// Destructive tools always go through ``AgentHost/confirm(title:message:isDestructive:)``.
    public var autoApproveReadOnly: Bool

    /// Maximum number of tool-calling loops before the agent gives up.
    public var maxToolIterations: Int

    /// Max tokens per assistant turn.
    public var maxTokens: Int

    public init(
        autoApproveReadOnly: Bool = true,
        maxToolIterations: Int = 8,
        maxTokens: Int = 1024
    ) {
        self.autoApproveReadOnly = autoApproveReadOnly
        self.maxToolIterations = maxToolIterations
        self.maxTokens = maxTokens
    }

    public static let `default` = AIAgentOptions()
}
