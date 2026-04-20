import Foundation

public struct ModelRecommendation: Sendable, Hashable {
    public let descriptor: ModelDescriptor
    public let reason: String
    public let score: Double
}

public actor ModelAdvisor {
    public init() {}

    public func recommend(
        from descriptors: [ModelDescriptor],
        preferModality: ModelModality? = nil,
        minContext: Int? = nil
    ) async -> [ModelRecommendation] {
        let gov = ResourceGovernor.shared
        let deviceClass = await gov.deviceClass()
        let ramCeiling: Int64
        switch deviceClass {
        case .highTier: ramCeiling = 6_000_000_000
        case .midTier: ramCeiling = 4_000_000_000
        case .lowTier: ramCeiling = 2_500_000_000
        case .constrained: ramCeiling = 1_500_000_000
        }
        return descriptors.compactMap { desc -> ModelRecommendation? in
            if let modality = preferModality, desc.modality != modality { return nil }
            if let minContext, desc.contextLength < minContext { return nil }
            if let required = desc.minRAMBytes, required > ramCeiling { return nil }
            var score = 1.0
            if let required = desc.minRAMBytes {
                score = Double(ramCeiling - required) / Double(ramCeiling)
            }
            let reason: String
            switch deviceClass {
            case .highTier: reason = "High-tier device: favouring larger quality models."
            case .midTier: reason = "Mid-tier device: balanced quality / speed."
            case .lowTier: reason = "Low-tier device: prioritising small, fast models."
            case .constrained: reason = "Constrained device: minimal-footprint model recommended."
            }
            return ModelRecommendation(descriptor: desc, reason: reason, score: score)
        }.sorted { $0.score > $1.score }
    }
}

public struct DownloadStatistics: Sendable, Codable {
    public var totalBytesDownloaded: Int64
    public var totalFiles: Int
    public var lastFinishedAt: Date?
    public var failures: Int

    public init(totalBytesDownloaded: Int64 = 0, totalFiles: Int = 0, lastFinishedAt: Date? = nil, failures: Int = 0) {
        self.totalBytesDownloaded = totalBytesDownloaded
        self.totalFiles = totalFiles
        self.lastFinishedAt = lastFinishedAt
        self.failures = failures
    }
}

public actor DownloadStatsTracker {
    public static let shared = DownloadStatsTracker()
    public private(set) var stats = DownloadStatistics()

    public func record(bytes: Int64, files: Int, success: Bool) {
        stats.totalBytesDownloaded += bytes
        stats.totalFiles += files
        if success {
            stats.lastFinishedAt = Date()
        } else {
            stats.failures += 1
        }
    }
}
