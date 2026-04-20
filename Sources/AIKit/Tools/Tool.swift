import Foundation

public struct ToolResult: Sendable, Hashable, Codable {
    public let text: String
    public let json: Data?
    public let isError: Bool

    public init(text: String, json: Data? = nil, isError: Bool = false) {
        self.text = text
        self.json = json
        self.isError = isError
    }

    public static func text(_ s: String) -> ToolResult { ToolResult(text: s) }
    public static func json<T: Encodable>(_ v: T) throws -> ToolResult {
        let data = try JSONEncoder().encode(v)
        let s = String(data: data, encoding: .utf8) ?? ""
        return ToolResult(text: s, json: data)
    }
    public static func error(_ message: String) -> ToolResult {
        ToolResult(text: message, isError: true)
    }
}

public protocol Tool: Sendable {
    var spec: ToolSpec { get }
    func execute(arguments: Data) async throws -> ToolResult
}

public struct TypedTool<Args: Decodable & Sendable, Out: Encodable & Sendable>: Tool {
    public let spec: ToolSpec
    private let handler: @Sendable (Args) async throws -> Out

    public init(
        spec: ToolSpec,
        handler: @Sendable @escaping (Args) async throws -> Out
    ) {
        self.spec = spec
        self.handler = handler
    }

    public func execute(arguments: Data) async throws -> ToolResult {
        do {
            let decoded: Args
            if arguments.isEmpty {
                let emptyDict = "{}".data(using: .utf8)!
                decoded = try JSONDecoder().decode(Args.self, from: emptyDict)
            } else {
                decoded = try JSONDecoder().decode(Args.self, from: arguments)
            }
            let out = try await handler(decoded)
            return try ToolResult.json(out)
        } catch let DecodingError.dataCorrupted(ctx) {
            throw AIError.toolArgumentsInvalid(tool: spec.name, reason: ctx.debugDescription)
        } catch let DecodingError.keyNotFound(key, _) {
            throw AIError.toolArgumentsInvalid(tool: spec.name, reason: "missing key '\(key.stringValue)'")
        } catch let DecodingError.typeMismatch(_, ctx) {
            throw AIError.toolArgumentsInvalid(tool: spec.name, reason: ctx.debugDescription)
        } catch {
            throw AIError.toolExecutionFailed(tool: spec.name, reason: error.localizedDescription)
        }
    }
}
