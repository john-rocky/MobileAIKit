import Foundation

public enum PrivacyClass: String, Sendable, Codable, Hashable {
    case `public`
    case personal
    case sensitive
    case secret
}

public struct PrivacyPolicy: Sendable {
    public var localOnly: Bool
    public var allowNetwork: Bool
    public var allowTelemetryExternal: Bool
    public var defaultClass: PrivacyClass
    public var storageClass: PrivacyClass

    public static let strictLocal = PrivacyPolicy(
        localOnly: true,
        allowNetwork: false,
        allowTelemetryExternal: false,
        defaultClass: .personal,
        storageClass: .sensitive
    )

    public static let permissive = PrivacyPolicy(
        localOnly: false,
        allowNetwork: true,
        allowTelemetryExternal: true,
        defaultClass: .public,
        storageClass: .public
    )

    public init(
        localOnly: Bool = false,
        allowNetwork: Bool = true,
        allowTelemetryExternal: Bool = false,
        defaultClass: PrivacyClass = .personal,
        storageClass: PrivacyClass = .personal
    ) {
        self.localOnly = localOnly
        self.allowNetwork = allowNetwork
        self.allowTelemetryExternal = allowTelemetryExternal
        self.defaultClass = defaultClass
        self.storageClass = storageClass
    }
}

public actor PrivacyGuard {
    public static let shared = PrivacyGuard()
    public private(set) var policy: PrivacyPolicy = .init()

    public func setPolicy(_ p: PrivacyPolicy) { policy = p }

    public func ensureNetworkAllowed() throws {
        if !policy.allowNetwork {
            throw AIError.permissionDenied("Network access is disabled by privacy policy")
        }
    }
}

public enum Redaction {
    public static func redact(_ text: String) -> String {
        var out = text
        let patterns: [(String, String)] = [
            ("[\\w.+-]+@[\\w-]+\\.[\\w.-]+", "[email]"),
            ("(\\+?\\d{1,3}[\\s-]?)?\\(?\\d{2,4}\\)?[\\s-]?\\d{3,4}[\\s-]?\\d{3,4}", "[phone]"),
            ("\\b\\d{3}-\\d{2}-\\d{4}\\b", "[ssn]"),
            ("\\b(?:\\d[ -]*?){13,16}\\b", "[card]"),
            ("\\b\\d{1,3}(?:\\.\\d{1,3}){3}\\b", "[ip]")
        ]
        for (p, replacement) in patterns {
            out = out.replacingOccurrences(of: p, with: replacement, options: .regularExpression)
        }
        return out
    }

    public static func redactor() -> @Sendable (String) -> String {
        { s in redact(s) }
    }
}

public struct SafetyPolicy: Sendable {
    public var blocklist: [String]
    public var promptInjectionDetector: (@Sendable (String) -> Bool)?
    public var maxUnsafeToolCallsBeforeBlock: Int

    public init(
        blocklist: [String] = [],
        promptInjectionDetector: (@Sendable (String) -> Bool)? = nil,
        maxUnsafeToolCallsBeforeBlock: Int = 3
    ) {
        self.blocklist = blocklist
        self.promptInjectionDetector = promptInjectionDetector
        self.maxUnsafeToolCallsBeforeBlock = maxUnsafeToolCallsBeforeBlock
    }

    public func check(input: String) throws {
        let lowered = input.lowercased()
        for term in blocklist where lowered.contains(term.lowercased()) {
            throw AIError.permissionDenied("Input violates safety blocklist")
        }
        if let detector = promptInjectionDetector, detector(input) {
            throw AIError.permissionDenied("Prompt injection detected")
        }
    }

    public static let defaultInjectionDetector: @Sendable (String) -> Bool = { input in
        let signals = [
            "ignore previous instructions",
            "ignore the above",
            "disregard prior",
            "system prompt override",
            "you are now",
            "forget your rules"
        ]
        let lowered = input.lowercased()
        return signals.contains { lowered.contains($0) }
    }
}
