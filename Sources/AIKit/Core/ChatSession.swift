import Foundation

@MainActor
@Observable
public final class ChatSession {
    public private(set) var messages: [Message] = []
    public private(set) var isGenerating: Bool = false
    public private(set) var lastUsage: GenerationUsage?
    public private(set) var lastError: AIError?
    public var systemPrompt: String?

    public let backend: any AIBackend
    public var tools: [ToolSpec]
    public var config: GenerationConfig
    public var memory: (any MemoryStoreProtocol)?
    public var retriever: Retriever?
    public var toolRegistry: ToolRegistry?
    public var telemetry: Telemetry?

    private var currentTask: Task<Void, Never>?

    public init(
        backend: any AIBackend,
        systemPrompt: String? = nil,
        tools: [ToolSpec] = [],
        config: GenerationConfig = .default,
        memory: (any MemoryStoreProtocol)? = nil,
        retriever: Retriever? = nil,
        toolRegistry: ToolRegistry? = nil,
        telemetry: Telemetry? = nil
    ) {
        self.backend = backend
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.config = config
        self.memory = memory
        self.retriever = retriever
        self.toolRegistry = toolRegistry
        self.telemetry = telemetry
    }

    /// Appends a user message and runs one generate-respond cycle, returning the assistant message.
    public func send(
        _ text: String,
        attachments: [Attachment] = []
    ) async throws -> Message {
        let userMessage = Message.user(text, attachments: attachments)
        messages.append(userMessage)
        return try await generate()
    }

    /// Appends a user message and streams assistant deltas.
    public func sendStream(
        _ text: String,
        attachments: [Attachment] = []
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        let userMessage = Message.user(text, attachments: attachments)
        messages.append(userMessage)
        return generateStream()
    }

    @discardableResult
    public func generate() async throws -> Message {
        isGenerating = true
        defer { isGenerating = false }

        let composed = try await composeMessages()
        let trace = telemetry?.beginSpan("generate")
        defer { trace?.end() }

        do {
            let result = try await backend.generate(
                messages: composed,
                tools: tools,
                config: config
            )
            lastUsage = result.usage
            messages.append(result.message)
            await telemetry?.record(usage: result.usage)

            if !result.message.toolCalls.isEmpty, let registry = toolRegistry {
                let toolMessages = try await registry.executeAll(
                    calls: result.message.toolCalls
                )
                messages.append(contentsOf: toolMessages)
                return try await generate()
            }

            try await persistToMemory(assistantMessage: result.message)
            return result.message
        } catch {
            let aiError = (error as? AIError) ?? .unknown(error.localizedDescription)
            lastError = aiError
            throw aiError
        }
    }

    public func generateStream() -> AsyncThrowingStream<GenerationChunk, Error> {
        let (stream, continuation) = AsyncThrowingStream<GenerationChunk, Error>.makeStream()
        let task = Task { @MainActor in
            self.isGenerating = true
            defer { self.isGenerating = false }

            do {
                let composed = try await self.composeMessages()
                var accumulated = ""
                var toolCalls: [ToolCall] = []
                var finishReason: FinishReason = .stop

                let backendStream = self.backend.stream(
                    messages: composed,
                    tools: self.tools,
                    config: self.config
                )

                for try await chunk in backendStream {
                    accumulated += chunk.delta
                    if let tc = chunk.toolCall {
                        toolCalls.append(tc)
                    }
                    continuation.yield(chunk)
                    if let reason = chunk.finishReason {
                        finishReason = reason
                    }
                    if chunk.finished { break }
                }

                let assistant = Message.assistant(accumulated, toolCalls: toolCalls)
                self.messages.append(assistant)

                if !toolCalls.isEmpty, let registry = self.toolRegistry {
                    let toolMessages = try await registry.executeAll(calls: toolCalls)
                    self.messages.append(contentsOf: toolMessages)
                    let nested = self.generateStream()
                    for try await chunk in nested {
                        continuation.yield(chunk)
                    }
                }

                try await self.persistToMemory(assistantMessage: assistant)
                _ = finishReason
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        self.currentTask = task
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    /// Cancels any in-flight generation. No-op otherwise.
    public func cancel() {
        currentTask?.cancel()
        isGenerating = false
    }

    /// Returns a ``ConversationSnapshot`` for persistence or undo.
    public func snapshot() -> ConversationSnapshot {
        ConversationSnapshot(
            id: UUID(),
            messages: messages,
            metadata: [:],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Restores messages from a ``ConversationSnapshot``.
    public func restore(_ snapshot: ConversationSnapshot) {
        messages = snapshot.messages
    }

    /// Clears messages. If `keepSystem` is true, keeps system-role messages.
    public func clear(keepSystem: Bool = true) {
        if keepSystem {
            messages = messages.filter { $0.role == .system }
        } else {
            messages.removeAll()
        }
    }

    private func composeMessages() async throws -> [Message] {
        var composed: [Message] = []
        if let systemPrompt {
            composed.append(.system(systemPrompt))
        }
        if let memory = memory {
            let memCtx = try await memory.context(for: messages.last?.content ?? "")
            if !memCtx.isEmpty {
                composed.append(.system("Relevant memory:\n\(memCtx)"))
            }
        }
        if let retriever = retriever, let lastUser = messages.last(where: { $0.role == .user }) {
            let docs = try await retriever.retrieve(query: lastUser.content)
            if !docs.isEmpty {
                let ctx = docs.map { "[\($0.source)] \($0.text)" }.joined(separator: "\n---\n")
                composed.append(.system("Context:\n\(ctx)"))
            }
        }
        composed.append(contentsOf: messages)
        return composed
    }

    private func persistToMemory(assistantMessage: Message) async throws {
        guard let memory = memory else { return }
        if let lastUser = messages.last(where: { $0.role == .user }) {
            try await memory.record(user: lastUser.content, assistant: assistantMessage.content)
        }
    }
}
