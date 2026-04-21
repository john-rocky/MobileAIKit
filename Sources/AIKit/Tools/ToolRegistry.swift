import Foundation

public actor ToolRegistry {
    private var tools: [String: any Tool] = [:]
    public var approvalHandler: (@Sendable (ToolSpec, Data) async -> Bool)?
    public var auditHandler: (@Sendable (ToolCall, ToolResult, TimeInterval) -> Void)?
    public var maxConcurrency: Int = 4
    public var cache: ToolResultCache?
    public var retry: ToolRetry?
    public var dryRun: Bool = false

    public init(
        approvalHandler: (@Sendable (ToolSpec, Data) async -> Bool)? = nil,
        cache: ToolResultCache? = nil,
        retry: ToolRetry? = nil
    ) {
        self.approvalHandler = approvalHandler
        self.cache = cache
        self.retry = retry
    }

    public func register(_ tool: any Tool) {
        tools[tool.spec.name] = tool
    }

    public func setApprovalHandler(_ handler: (@Sendable (ToolSpec, Data) async -> Bool)?) {
        self.approvalHandler = handler
    }

    public func setAuditHandler(_ handler: (@Sendable (ToolCall, ToolResult, TimeInterval) -> Void)?) {
        self.auditHandler = handler
    }

    public func register<Args: Decodable & Sendable, Out: Encodable & Sendable>(
        name: String,
        description: String,
        parameters: JSONSchema,
        requiresApproval: Bool = false,
        sideEffectFree: Bool = true,
        handler: @Sendable @escaping (Args) async throws -> Out
    ) {
        let spec = ToolSpec(
            name: name,
            description: description,
            parameters: parameters,
            requiresApproval: requiresApproval,
            sideEffectFree: sideEffectFree
        )
        let tool = TypedTool(spec: spec, handler: handler)
        register(tool)
    }

    public func specs() -> [ToolSpec] {
        tools.values.map(\.spec).sorted { $0.name < $1.name }
    }

    public func unregister(_ name: String) {
        tools.removeValue(forKey: name)
    }

    public func execute(call: ToolCall) async throws -> ToolResult {
        guard let tool = tools[call.name] else {
            throw AIError.toolNotFound(call.name)
        }
        let data = call.arguments.data(using: .utf8) ?? Data()

        if tool.spec.requiresApproval {
            let approved = await approvalHandler?(tool.spec, data) ?? false
            if !approved { throw AIError.approvalDenied }
        }

        if dryRun {
            let payload: [String: Any] = ["dryRun": true, "tool": call.name, "arguments": call.arguments]
            let body = (try? JSONSerialization.data(withJSONObject: payload).map { $0 }) ?? Data()
            return ToolResult(text: String(data: body, encoding: .utf8) ?? "dry-run", json: body)
        }

        let cacheKey = ToolResultCache.key(toolName: call.name, arguments: call.arguments)
        if tool.spec.sideEffectFree, let cache, let cached = await cache.get(key: cacheKey) {
            auditHandler?(call, cached, 0)
            return cached
        }

        let start = Date()
        let operation: @Sendable () async throws -> ToolResult = {
            if let timeout = tool.spec.timeout {
                return try await withThrowingTimeout(seconds: timeout) {
                    try await tool.execute(arguments: data)
                }
            } else {
                return try await tool.execute(arguments: data)
            }
        }
        let result: ToolResult
        if let retry {
            result = try await retry.run(operation)
        } else {
            result = try await operation()
        }
        let elapsed = Date().timeIntervalSince(start)
        auditHandler?(call, result, elapsed)
        if tool.spec.sideEffectFree, let cache {
            await cache.put(key: cacheKey, value: result)
        }
        return result
    }

    public func executeAll(calls: [ToolCall]) async throws -> [Message] {
        try await withThrowingTaskGroup(of: (ToolCall, ToolResult).self) { group in
            var iter = calls.makeIterator()
            var inflight = 0
            var results: [(ToolCall, ToolResult)] = []

            while let call = iter.next() {
                if inflight >= maxConcurrency {
                    if let finished = try await group.next() {
                        results.append(finished)
                        inflight -= 1
                    }
                }
                group.addTask { [self] in
                    let result = try await self.execute(call: call)
                    return (call, result)
                }
                inflight += 1
            }

            while let finished = try await group.next() {
                results.append(finished)
            }

            return results.map { call, res in
                Message.tool(res.text, toolCallId: call.id, name: call.name)
            }
        }
    }
}

private func withThrowingTimeout<T: Sendable>(
    seconds: TimeInterval,
    _ op: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await op() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AIError.timeout
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
