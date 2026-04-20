import Foundation

public enum ModelFormat: String, Sendable, Codable, Hashable {
    case gguf
    case mlx
    case coreml
    case safetensors
    case onnx
    case custom
}

public enum ModelModality: String, Sendable, Codable, Hashable {
    case text
    case vision
    case audio
    case embedding
}

public struct ModelFile: Sendable, Codable, Hashable {
    public let relativePath: String
    public let url: URL
    public let expectedBytes: Int64?
    public let sha256: String?

    public init(relativePath: String, url: URL, expectedBytes: Int64? = nil, sha256: String? = nil) {
        self.relativePath = relativePath
        self.url = url
        self.expectedBytes = expectedBytes
        self.sha256 = sha256
    }
}

public struct ModelDescriptor: Sendable, Codable, Hashable, Identifiable {
    public var id: String { "\(name)@\(version)" }
    public let name: String
    public let version: String
    public let format: ModelFormat
    public let modality: ModelModality
    public let contextLength: Int
    public let files: [ModelFile]
    public let tokenizer: ModelFile?
    public let chatTemplate: String?
    public let license: String?
    public let displayName: String
    public let minIOSVersion: String?
    public let minRAMBytes: Int64?

    public init(
        name: String,
        version: String,
        format: ModelFormat,
        modality: ModelModality = .text,
        contextLength: Int = 4096,
        files: [ModelFile],
        tokenizer: ModelFile? = nil,
        chatTemplate: String? = nil,
        license: String? = nil,
        displayName: String? = nil,
        minIOSVersion: String? = nil,
        minRAMBytes: Int64? = nil
    ) {
        self.name = name
        self.version = version
        self.format = format
        self.modality = modality
        self.contextLength = contextLength
        self.files = files
        self.tokenizer = tokenizer
        self.chatTemplate = chatTemplate
        self.license = license
        self.displayName = displayName ?? name
        self.minIOSVersion = minIOSVersion
        self.minRAMBytes = minRAMBytes
    }
}
