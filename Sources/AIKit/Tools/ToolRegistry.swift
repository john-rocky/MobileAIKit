import Foundation

public actor ToolRegistry {
    private var tools: [String: any Tool] = [:]
    public var approvalHandler: (@Sendable (ToolSpec, Data) async -> Bool)?
    public var auditHandler: (@Sendable (ToolCall, ToolResult, TimeInterval) -> Void)?
    public var maxConcurrency: Int = 4

    public init(approvalHandler: (@Sendable (ToolSpec, Data) async -> Bool)? = nil) {
        self.approvalHandler = approvalHandler
    }

    public func register(_ tool: any Tool) {
        tools[tool.spec.name] = tool
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

        let start = Date()
        let result: ToolResult
        if let timeout = tool.spec.timeout {
            result = try await withThrowingTimeout(seconds: timeout) {
                try await tool.execute(arguments: data)
            }
        } else {
            result = try await tool.execute(arguments: data)
        }
        let elapsed = Date().timeIntervalSince(start)
        auditHandler?(call, result, elapsed)
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
