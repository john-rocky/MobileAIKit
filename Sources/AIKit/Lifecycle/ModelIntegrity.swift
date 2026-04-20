import Foundation

public actor ModelIntegrityChecker {
    public let cache: ModelCache

    public init(cache: ModelCache = ModelCache.shared) {
        self.cache = cache
    }

    public func verify(_ descriptor: ModelDescriptor) async throws -> Bool {
        guard await cache.isDownloaded(descriptor) else { return false }
        do {
            try await cache.verifyChecksum(descriptor)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func autoRepair(
        _ descriptor: ModelDescriptor,
        downloader: ModelDownloader
    ) async throws -> URL {
        if try await verify(descriptor) {
            return await cache.directory(for: descriptor)
        }
        try await cache.remove(descriptor)
        return try await downloader.ensure(descriptor)
    }
}

public actor ModelRollback {
    private var snapshots: [String: [String]] = [:]

    public init() {}

    public func snapshot(_ descriptor: ModelDescriptor) async {
        snapshots[descriptor.name, default: []].append(descriptor.version)
        if snapshots[descriptor.name]!.count > 5 {
            snapshots[descriptor.name]!.removeFirst()
        }
    }

    public func previousVersion(of name: String) -> String? {
        guard let history = snapshots[name], history.count >= 2 else { return nil }
        return history[history.count - 2]
    }
}
