import Foundation

public protocol AIBackendResolver: Sendable {
    static var name: String { get }
    static func make() -> any AIBackend
}

public actor AIBackendRegistry {
    public static let shared = AIBackendRegistry()
    private var factories: [String: @Sendable () async throws -> any AIBackend] = [:]

    public func register(name: String, factory: @Sendable @escaping () async throws -> any AIBackend) {
        factories[name] = factory
    }

    public func resolve(name: String) async throws -> any AIBackend {
        guard let factory = factories[name] else {
            throw AIError.unsupportedBackend(name)
        }
        return try await factory()
    }

    public func names() -> [String] { Array(factories.keys) }
}
