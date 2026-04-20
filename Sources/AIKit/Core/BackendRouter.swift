import Foundation

public actor BackendRouter: AIBackend {
    public let info: BackendInfo
    public private(set) var backends: [any AIBackend]
    public var selectionPolicy: SelectionPolicy

    public enum SelectionPolicy: Sendable {
        case firstAvailable
        case capability(BackendCapabilities)
        case priority([String])
    }

    public init(
        backends: [any AIBackend],
        selectionPolicy: SelectionPolicy = .firstAvailable
    ) {
        precondition(!backends.isEmpty, "BackendRouter requires at least one backend")
        self.backends = backends
        self.selectionPolicy = selectionPolicy
        let caps = backends.reduce(BackendCapabilities()) { $0.union($1.info.capabilities) }
        let maxCtx = backends.map(\.info.contextLength).max() ?? 0
        self.info = BackendInfo(
            name: "router(\(backends.map(\.info.name).joined(separator: "|")))",
            version: "1.0",
            capabilities: caps,
            contextLength: maxCtx,
            preferredDevice: "mixed"
        )
    }

    public func setBackends(_ new: [any AIBackend]) {
        precondition(!new.isEmpty)
        self.backends = new
    }

    public var isLoaded: Bool {
        get async {
            for b in backends {
                if await b.isLoaded { return true }
            }
            return false
        }
    }

    public func load() async throws {
        try await select().load()
    }

    public func unload() async {
        for b in backends { await b.unload() }
    }

    public func generate(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) async throws -> GenerationResult {
        var lastError: Error?
        for backend in orderedBackends(for: messages) {
            do {
                return try await backend.generate(messages: messages, tools: tools, config: config)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? AIError.unknown("All backends failed")
    }

    public nonisolated func stream(
        messages: [Message],
        tools: [ToolSpec],
        config: GenerationConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let chosen = try await self.select()
                    for try await chunk in chosen.stream(messages: messages, tools: tools, config: config) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func tokenCount(for messages: [Message]) async throws -> Int {
        try await select().tokenCount(for: messages)
    }

    public func embed(_ text: String) async throws -> [Float] {
        for backend in backends where backend.info.capabilities.contains(.embeddings) {
            return try await backend.embed(text)
        }
        throw AIError.unsupportedCapability("embeddings")
    }

    func select() async throws -> any AIBackend {
        switch selectionPolicy {
        case .firstAvailable:
            return backends.first ?? { fatalError() }()
        case .capability(let required):
            guard let found = backends.first(where: { $0.info.capabilities.isSuperset(of: required) }) else {
                throw AIError.unsupportedCapability(String(describing: required))
            }
            return found
        case .priority(let names):
            for name in names {
                if let b = backends.first(where: { $0.info.name == name }) { return b }
            }
            return backends.first ?? { fatalError() }()
        }
    }

    func orderedBackends(for messages: [Message]) -> [any AIBackend] {
        let needsVision = messages.contains { !$0.attachments.isEmpty }
        if needsVision {
            return backends.sorted { a, b in
                let av = a.info.capabilities.contains(.vision) ? 1 : 0
                let bv = b.info.capabilities.contains(.vision) ? 1 : 0
                return av > bv
            }
        }
        return backends
    }
}
