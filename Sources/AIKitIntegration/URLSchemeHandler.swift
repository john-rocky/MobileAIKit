import Foundation
import AIKit

public struct URLSchemeRoute: Sendable {
    public let scheme: String
    public let host: String?
    public let handler: @Sendable (URLComponents) async throws -> Void

    public init(scheme: String, host: String? = nil, handler: @Sendable @escaping (URLComponents) async throws -> Void) {
        self.scheme = scheme
        self.host = host
        self.handler = handler
    }
}

public actor URLSchemeRouter {
    public static let shared = URLSchemeRouter()
    private var routes: [URLSchemeRoute] = []

    public func register(_ route: URLSchemeRoute) { routes.append(route) }

    public func handle(_ url: URL) async -> Bool {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        for route in routes {
            if route.scheme == comps.scheme && (route.host == nil || route.host == comps.host) {
                try? await route.handler(comps)
                return true
            }
        }
        return false
    }
}

public struct UniversalLinkRoute: Sendable {
    public let host: String
    public let handler: @Sendable (URLComponents) async throws -> Void

    public init(host: String, handler: @Sendable @escaping (URLComponents) async throws -> Void) {
        self.host = host
        self.handler = handler
    }
}

public actor UniversalLinkRouter {
    public static let shared = UniversalLinkRouter()
    private var routes: [UniversalLinkRoute] = []

    public func register(_ route: UniversalLinkRoute) { routes.append(route) }

    public func handle(_ url: URL) async -> Bool {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.host else { return false }
        for route in routes where route.host == host {
            try? await route.handler(comps)
            return true
        }
        return false
    }
}
