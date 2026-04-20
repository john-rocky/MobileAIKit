import Foundation

public struct DownloadProgress: Sendable, Hashable {
    public let fileIndex: Int
    public let fileCount: Int
    public let file: String
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let overallBytesDownloaded: Int64
    public let overallTotalBytes: Int64

    public var fraction: Double {
        overallTotalBytes > 0 ? Double(overallBytesDownloaded) / Double(overallTotalBytes) : 0
    }
}

public actor ModelDownloader {
    private let cache: ModelCache
    private let session: URLSession
    private var active: [String: Task<Void, Error>] = [:]

    public init(
        cache: ModelCache = ModelCache.shared,
        session: URLSession = .shared
    ) {
        self.cache = cache
        self.session = session
    }

    public func ensure(
        _ descriptor: ModelDescriptor,
        verifyChecksum: Bool = true,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        if await cache.isDownloaded(descriptor) {
            if verifyChecksum { try? await cache.verifyChecksum(descriptor) }
            await cache.bumpAccess(descriptor)
            return await cache.directory(for: descriptor)
        }

        if let existing = active[descriptor.id] {
            try await existing.value
            return await cache.directory(for: descriptor)
        }

        let task = Task<Void, Error> { [cache, session] in
            let dir = await cache.directory(for: descriptor)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            var files = descriptor.files
            if let tok = descriptor.tokenizer { files.append(tok) }

            let total = files.reduce(Int64(0)) { $0 + ($1.expectedBytes ?? 0) }
            var overallDone: Int64 = 0

            for (idx, file) in files.enumerated() {
                let dest = await cache.fileURL(for: descriptor, file: file)
                if FileManager.default.fileExists(atPath: dest.path) {
                    let sz = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.int64Value ?? 0
                    if let expected = file.expectedBytes, sz == expected {
                        overallDone += sz
                        continue
                    }
                }
                try FileManager.default.createDirectory(
                    at: dest.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try await Self.downloadResumable(
                    from: file.url,
                    to: dest,
                    session: session,
                    onChunk: { downloaded, totalForFile in
                        let report = DownloadProgress(
                            fileIndex: idx,
                            fileCount: files.count,
                            file: file.relativePath,
                            bytesDownloaded: downloaded,
                            totalBytes: totalForFile,
                            overallBytesDownloaded: overallDone + downloaded,
                            overallTotalBytes: max(total, overallDone + totalForFile)
                        )
                        progress?(report)
                    }
                )
                let sz = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.int64Value ?? 0
                overallDone += sz
            }

            if verifyChecksum {
                try await cache.verifyChecksum(descriptor)
            }
            try await cache.evictLRUIfNeeded(keeping: [descriptor.id])
        }

        active[descriptor.id] = task
        defer { active.removeValue(forKey: descriptor.id) }
        try await task.value
        return await cache.directory(for: descriptor)
    }

    public func cancel(_ descriptor: ModelDescriptor) {
        active[descriptor.id]?.cancel()
        active.removeValue(forKey: descriptor.id)
    }

    static func downloadResumable(
        from url: URL,
        to dest: URL,
        session: URLSession,
        onChunk: @Sendable (Int64, Int64) -> Void
    ) async throws {
        let partURL = dest.appendingPathExtension("part")
        var request = URLRequest(url: url)
        let existingSize: Int64 = {
            let attrs = try? FileManager.default.attributesOfItem(atPath: partURL.path)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }()
        if existingSize > 0 {
            request.setValue("bytes=\(existingSize)-", forHTTPHeaderField: "Range")
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.downloadFailed("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw AIError.downloadFailed("HTTP \(http.statusCode)")
        }

        let total = http.expectedContentLength + existingSize

        if !FileManager.default.fileExists(atPath: partURL.path) {
            FileManager.default.createFile(atPath: partURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: partURL)
        try handle.seek(toOffset: UInt64(existingSize))
        defer { try? handle.close() }

        var buffer = Data()
        buffer.reserveCapacity(1 << 20)
        var written: Int64 = existingSize

        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count >= (1 << 20) {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                onChunk(written, total)
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            written += Int64(buffer.count)
            onChunk(written, total)
        }
        try handle.close()
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: partURL, to: dest)
    }
}
