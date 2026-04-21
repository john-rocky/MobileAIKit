import Foundation

public struct AdapterDescriptor: Sendable, Codable, Hashable {
    public let name: String
    public let version: String
    public let baseModelName: String
    public let files: [ModelFile]
    public let capability: String
    public let tags: [String]

    public init(
        name: String,
        version: String,
        baseModelName: String,
        files: [ModelFile],
        capability: String,
        tags: [String] = []
    ) {
        self.name = name
        self.version = version
        self.baseModelName = baseModelName
        self.files = files
        self.capability = capability
        self.tags = tags
    }
}

public actor AdapterRegistry {
    public static let shared = AdapterRegistry()
    private var adapters: [String: AdapterDescriptor] = [:]
    private var activeAdapter: String?
    private var experimentVariant: [String: String] = [:]

    public func register(_ adapter: AdapterDescriptor) {
        adapters["\(adapter.name)@\(adapter.version)"] = adapter
    }

    public func allAdapters(forBase base: String) -> [AdapterDescriptor] {
        adapters.values.filter { $0.baseModelName == base }
    }

    public func setActive(_ id: String?) {
        activeAdapter = id
    }

    public func active() -> AdapterDescriptor? {
        activeAdapter.flatMap { adapters[$0] }
    }

    public func registerExperiment(name: String, variants: [String]) {
        guard !variants.isEmpty else { return }
        let hash = abs(name.hashValue)
        let pick = variants[hash % variants.count]
        experimentVariant[name] = pick
    }

    public func variant(for experiment: String) -> String? {
        experimentVariant[experiment]
    }
}

public actor AdapterDownloader {
    public let downloader: HFModelDownloader

    public init(downloader: HFModelDownloader = HFModelDownloader()) {
        self.downloader = downloader
    }

    public func ensure(_ adapter: AdapterDescriptor) async throws -> URL {
        let shim = ModelDescriptor(
            name: "adapter-\(adapter.name)",
            version: adapter.version,
            format: .custom,
            files: adapter.files,
            displayName: adapter.name
        )
        return try await downloader.ensure(shim)
    }
}
