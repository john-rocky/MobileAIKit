import Foundation

public extension AIKit {
    @MainActor
    static func quickStart(
        systemPrompt: String? = nil,
        registryName: String = "default"
    ) async throws -> ChatSession {
        let backend = try await AIBackendRegistry.shared.resolve(name: registryName)
        return ChatSession(backend: backend, systemPrompt: systemPrompt)
    }
}
