import Foundation
import AIKit

struct Moment: Codable, Identifiable, Hashable {
    let id: UUID
    var createdAt: Date
    var title: String
    var narrative: String
    var tags: [String]
    var rows: [Row]
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    var mood: String?
    var imageFileName: String?
    var audioFileName: String?
    var audioTranscript: String?

    struct Row: Codable, Hashable, Identifiable {
        var id: String { label }
        let label: String
        let value: String
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        narrative: String,
        tags: [String] = [],
        rows: [Row] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        mood: String? = nil,
        imageFileName: String? = nil,
        audioFileName: String? = nil,
        audioTranscript: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.narrative = narrative
        self.tags = tags
        self.rows = rows
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.mood = mood
        self.imageFileName = imageFileName
        self.audioFileName = audioFileName
        self.audioTranscript = audioTranscript
    }

    var embedText: String {
        var parts: [String] = [title, narrative]
        if !tags.isEmpty { parts.append("Tags: " + tags.joined(separator: ", ")) }
        if let placeName { parts.append("Place: \(placeName)") }
        if let mood { parts.append("Mood: \(mood)") }
        if let audioTranscript, !audioTranscript.isEmpty { parts.append("Voice: \(audioTranscript)") }
        for row in rows { parts.append("\(row.label): \(row.value)") }
        return parts.joined(separator: "\n")
    }
}

struct MomentExtraction: Codable {
    let title: String
    let narrative: String
    let tags: [String]
    let rows: [Moment.Row]
    let mood: String?

    static let schema: JSONSchema = .object(
        properties: [
            "title": .string(description: "3-6 word evocative title"),
            "narrative": .string(description: "2-4 sentence description weaving together the photo and the voice note"),
            "tags": .array(items: .string(), maxItems: 6),
            "rows": .array(items: .object(
                properties: ["label": .string(), "value": .string()],
                required: ["label", "value"]
            ), maxItems: 4),
            "mood": .string(enumValues: ["happy", "calm", "nostalgic", "focused", "excited", "grateful", "tired", "sad", "anxious"])
        ],
        required: ["title", "narrative", "tags", "rows"]
    )
}
