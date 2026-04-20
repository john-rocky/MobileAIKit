import Foundation

public struct PlanStep: Sendable, Hashable, Codable {
    public let description: String
    public let tool: String
    public let arguments: String
}

public struct Plan: Sendable, Hashable, Codable {
    public let goal: String
    public let steps: [PlanStep]
}

public actor PlanExecutor {
    public let backend: any AIBackend
    public let tools: ToolRegistry

    public init(backend: any AIBackend, tools: ToolRegistry) {
        self.backend = backend
        self.tools = tools
    }

    public func plan(goal: String) async throws -> Plan {
        let specs = await tools.specs()
        let toolDump = specs.map { "- \($0.name): \($0.description)" }.joined(separator: "\n")
        let schema: JSONSchema = .object(
            properties: [
                "goal": .string(),
                "steps": .array(items: .object(
                    properties: [
                        "description": .string(),
                        "tool": .string(enumValues: specs.map(\.name)),
                        "arguments": .string(description: "JSON-encoded arguments string")
                    ],
                    required: ["description", "tool", "arguments"]
                ))
            ],
            required: ["goal", "steps"]
        )
        return try await AIKit.extract(
            Plan.self,
            from: "Goal: \(goal)\n\nAvailable tools:\n\(toolDump)",
            schema: schema,
            instruction: "Break the goal into a sequential list of tool calls. Each step's arguments must be a valid JSON string.",
            backend: backend
        )
    }

    public func execute(plan: Plan) async throws -> [(PlanStep, ToolResult)] {
        var results: [(PlanStep, ToolResult)] = []
        for step in plan.steps {
            let call = ToolCall(id: UUID().uuidString, name: step.tool, arguments: step.arguments)
            let result = try await tools.execute(call: call)
            results.append((step, result))
        }
        return results
    }

    public func run(goal: String) async throws -> (Plan, [(PlanStep, ToolResult)]) {
        let plan = try await self.plan(goal: goal)
        let outcome = try await execute(plan: plan)
        return (plan, outcome)
    }
}
