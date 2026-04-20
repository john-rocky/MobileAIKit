import Foundation

public enum AIError: LocalizedError, Sendable {
    case modelNotLoaded
    case modelNotFound(String)
    case modelLoadFailed(String)
    case tokenizerNotFound
    case unsupportedBackend(String)
    case unsupportedCapability(String)
    case invalidConfiguration(String)
    case generationFailed(String)
    case contextLengthExceeded(limit: Int, requested: Int)
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case decodingFailed(String)
    case toolExecutionFailed(tool: String, reason: String)
    case toolArgumentsInvalid(tool: String, reason: String)
    case toolNotFound(String)
    case approvalDenied
    case cancelled
    case timeout
    case resourceUnavailable(String)
    case thermalPressure
    case outOfMemory
    case permissionDenied(String)
    case networkUnavailable
    case invalidAttachment(String)
    case schemaMismatch(String)
    case streamingUnsupported
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Model is not loaded."
        case .modelNotFound(let name): return "Model not found: \(name)"
        case .modelLoadFailed(let reason): return "Failed to load model: \(reason)"
        case .tokenizerNotFound: return "Tokenizer not found."
        case .unsupportedBackend(let name): return "Unsupported backend: \(name)"
        case .unsupportedCapability(let cap): return "Capability not supported: \(cap)"
        case .invalidConfiguration(let reason): return "Invalid configuration: \(reason)"
        case .generationFailed(let reason): return "Generation failed: \(reason)"
        case .contextLengthExceeded(let limit, let requested):
            return "Context length exceeded. Limit \(limit), requested \(requested)."
        case .downloadFailed(let reason): return "Download failed: \(reason)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch. Expected \(expected), got \(actual)."
        case .decodingFailed(let reason): return "Decoding failed: \(reason)"
        case .toolExecutionFailed(let tool, let reason):
            return "Tool '\(tool)' execution failed: \(reason)"
        case .toolArgumentsInvalid(let tool, let reason):
            return "Tool '\(tool)' arguments invalid: \(reason)"
        case .toolNotFound(let name): return "Tool not found: \(name)"
        case .approvalDenied: return "User denied approval."
        case .cancelled: return "Operation cancelled."
        case .timeout: return "Operation timed out."
        case .resourceUnavailable(let r): return "Resource unavailable: \(r)"
        case .thermalPressure: return "Device under thermal pressure."
        case .outOfMemory: return "Out of memory."
        case .permissionDenied(let p): return "Permission denied: \(p)"
        case .networkUnavailable: return "Network unavailable."
        case .invalidAttachment(let reason): return "Invalid attachment: \(reason)"
        case .schemaMismatch(let reason): return "Schema mismatch: \(reason)"
        case .streamingUnsupported: return "Streaming is not supported by this backend."
        case .unknown(let reason): return "Unknown error: \(reason)"
        }
    }
}
