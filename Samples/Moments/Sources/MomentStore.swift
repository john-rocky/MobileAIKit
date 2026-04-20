import Foundation
import SwiftUI
import AIKit

@MainActor
@Observable
final class MomentStore {
    private(set) var moments: [Moment] = []

    let memory: DatabaseMemoryStore
    let embedder: any Embedder
    let mediaDirectory: URL
    private let journalURL: URL

    init() throws {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDir = base.appendingPathComponent("Moments", isDirectory: true)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.mediaDirectory = appDir.appendingPathComponent("media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        self.journalURL = appDir.appendingPathComponent("journal.json")

        self.embedder = HashingEmbedder(dimension: 384)
        self.memory = try DatabaseMemoryStore(
            fileURL: appDir.appendingPathComponent("memory.sqlite3"),
            embedder: self.embedder,
            maxShortTerm: 2_000
        )

        load()
    }

    func add(_ moment: Moment) async throws {
        moments.insert(moment, at: 0)
        try save()

        var metadata: [String: String] = [
            "momentId": moment.id.uuidString,
            "title": moment.title
        ]
        if let place = moment.placeName { metadata["place"] = place }
        if let mood = moment.mood { metadata["mood"] = mood }
        if let lat = moment.latitude { metadata["lat"] = String(lat) }
        if let lng = moment.longitude { metadata["lng"] = String(lng) }

        try await memory.store(MemoryRecord(
            id: moment.id,
            kind: .episodic,
            namespace: "moments",
            text: moment.embedText,
            entities: moment.tags,
            importance: 0.8,
            source: moment.placeName,
            metadata: metadata
        ))
    }

    func delete(_ moment: Moment) async throws {
        moments.removeAll { $0.id == moment.id }
        try save()
        if let image = moment.imageFileName { try? FileManager.default.removeItem(at: mediaDirectory.appendingPathComponent(image)) }
        if let audio = moment.audioFileName { try? FileManager.default.removeItem(at: mediaDirectory.appendingPathComponent(audio)) }
        try await memory.forget(id: moment.id)
    }

    func search(_ query: String, limit: Int = 12) async throws -> [Moment] {
        let hits = try await memory.retrieve(query: query, namespace: "moments", limit: limit)
        let ids = hits.compactMap { UUID(uuidString: $0.metadata["momentId"] ?? "") }
        let lookup = Dictionary(uniqueKeysWithValues: moments.map { ($0.id, $0) })
        return ids.compactMap { lookup[$0] }
    }

    func moment(id: UUID) -> Moment? {
        moments.first { $0.id == id }
    }

    func imageURL(for moment: Moment) -> URL? {
        moment.imageFileName.map { mediaDirectory.appendingPathComponent($0) }
    }

    func audioURL(for moment: Moment) -> URL? {
        moment.audioFileName.map { mediaDirectory.appendingPathComponent($0) }
    }

    // MARK: - Persistence

    private func save() throws {
        let data = try JSONEncoder().encode(moments)
        try data.write(to: journalURL, options: .atomic)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: journalURL.path),
              let data = try? Data(contentsOf: journalURL),
              let decoded = try? JSONDecoder().decode([Moment].self, from: data) else {
            return
        }
        self.moments = decoded
    }
}
