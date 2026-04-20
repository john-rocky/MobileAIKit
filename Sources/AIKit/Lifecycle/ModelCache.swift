import Foundation
import CryptoKit

public actor ModelCache {
    public static let shared = try! ModelCache()

    public let root: URL
    public var diskQuotaBytes: Int64

    public init(
        root: URL? = nil,
        diskQuotaBytes: Int64 = 16_000_000_000
    ) throws {
        if let root {
            self.root = root
        } else {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.root = base.appendingPathComponent("AIKit/Models", isDirectory: true)
        }
        self.diskQuotaBytes = diskQuotaBytes
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    public func directory(for descriptor: ModelDescriptor) -> URL {
        root.appendingPathComponent(descriptor.name, isDirectory: true)
            .appendingPathComponent(descriptor.version, isDirectory: true)
    }

    public func fileURL(for descriptor: ModelDescriptor, file: ModelFile) -> URL {
        directory(for: descriptor).appendingPathComponent(file.relativePath)
    }

    public func isDownloaded(_ descriptor: ModelDescriptor) -> Bool {
        let fm = FileManager.default
        for file in descriptor.files {
            let url = fileURL(for: descriptor, file: file)
            guard fm.fileExists(atPath: url.path) else { return false }
            if let expected = file.expectedBytes {
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                if size != expected { return false }
            }
        }
        if let tokenizer = descriptor.tokenizer {
            let url = fileURL(for: descriptor, file: tokenizer)
            if !fm.fileExists(atPath: url.path) { return false }
        }
        return true
    }

    public func bumpAccess(_ descriptor: ModelDescriptor) {
        let dir = directory(for: descriptor)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: dir.path
        )
    }

    public func remove(_ descriptor: ModelDescriptor) throws {
        let dir = directory(for: descriptor)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    public func totalUsedBytes() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if values?.isDirectory == true { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    public func evictLRUIfNeeded(keeping: Set<String> = []) throws {
        var used = totalUsedBytes()
        guard used > diskQuotaBytes else { return }
        let fm = FileManager.default
        let modelDirs = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])
        var entries: [(URL, Date, Int64)] = []
        for dir in modelDirs {
            let versionDirs = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for v in versionDirs {
                let id = "\(dir.lastPathComponent)@\(v.lastPathComponent)"
                if keeping.contains(id) { continue }
                let date = (try? v.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let size = folderSize(at: v)
                entries.append((v, date, size))
            }
        }
        entries.sort { $0.1 < $1.1 }
        for (url, _, size) in entries {
            if used <= diskQuotaBytes { break }
            try? fm.removeItem(at: url)
            used -= size
        }
    }

    private func folderSize(at url: URL) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        for case let sub as URL in enumerator {
            let values = try? sub.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    public func verifyChecksum(_ descriptor: ModelDescriptor) async throws {
        for file in descriptor.files {
            guard let expected = file.sha256 else { continue }
            let url = fileURL(for: descriptor, file: file)
            let hash = try await Self.sha256(of: url)
            if hash != expected {
                throw AIError.checksumMismatch(expected: expected, actual: hash)
            }
        }
    }

    public static func sha256(of url: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            while true {
                let chunk = handle.readData(ofLength: 1 << 20)
                if chunk.isEmpty { break }
                hasher.update(data: chunk)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }
}
