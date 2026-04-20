import Foundation
import SwiftUI

@MainActor
@Observable
final class MeetingStore {
    private(set) var meetings: [Meeting] = []
    private let file: URL

    init() throws {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent("MeetingSummarizer", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.file = dir.appendingPathComponent("meetings.json")
        load()
    }

    func add(_ meeting: Meeting) throws {
        meetings.insert(meeting, at: 0)
        try save()
    }

    func delete(_ meeting: Meeting) throws {
        meetings.removeAll { $0.id == meeting.id }
        try save()
    }

    private func save() throws {
        try JSONEncoder().encode(meetings).write(to: file, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([Meeting].self, from: data) else { return }
        self.meetings = decoded
    }
}
