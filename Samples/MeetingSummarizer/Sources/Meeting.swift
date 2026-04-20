import Foundation
import AIKit

struct Meeting: Codable, Identifiable, Hashable {
    let id: UUID
    var startedAt: Date
    var durationSeconds: Double
    var title: String
    var transcript: String
    var summary: String
    var decisions: [String]
    var actionItems: [ActionItem]
    var risks: [String]
    var openQuestions: [String]

    struct ActionItem: Codable, Hashable, Identifiable {
        var id: String { "\(owner ?? "?"):\(task)" }
        let owner: String?
        let task: String
        let due: String?
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        durationSeconds: Double,
        title: String,
        transcript: String,
        summary: String,
        decisions: [String],
        actionItems: [ActionItem],
        risks: [String],
        openQuestions: [String]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.title = title
        self.transcript = transcript
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.risks = risks
        self.openQuestions = openQuestions
    }

    var spokenSummary: String {
        var parts: [String] = ["Summary: \(summary)"]
        if !decisions.isEmpty {
            parts.append("Decisions. " + decisions.enumerated().map { "\($0.offset + 1). \($0.element)." }.joined(separator: " "))
        }
        if !actionItems.isEmpty {
            let joined = actionItems.map {
                let owner = $0.owner ?? "someone"
                let due = $0.due.map { ", due \($0)" } ?? ""
                return "\(owner) to \($0.task)\(due)"
            }.joined(separator: "; ")
            parts.append("Action items. \(joined).")
        }
        if !risks.isEmpty {
            parts.append("Risks. " + risks.joined(separator: "; ") + ".")
        }
        if !openQuestions.isEmpty {
            parts.append("Open questions. " + openQuestions.joined(separator: "; ") + ".")
        }
        return parts.joined(separator: " ")
    }
}

struct MeetingExtraction: Codable {
    let title: String
    let summary: String
    let decisions: [String]
    let actionItems: [Meeting.ActionItem]
    let risks: [String]
    let openQuestions: [String]

    static let schema: JSONSchema = .object(
        properties: [
            "title": .string(description: "3-6 word title for this meeting"),
            "summary": .string(description: "2-3 sentence plain-English summary"),
            "decisions": .array(items: .string()),
            "actionItems": .array(items: .object(
                properties: [
                    "owner": .string(),
                    "task": .string(),
                    "due": .string(description: "date or phrase such as 'next Friday'")
                ],
                required: ["task"]
            )),
            "risks": .array(items: .string()),
            "openQuestions": .array(items: .string())
        ],
        required: ["title", "summary", "decisions", "actionItems", "risks", "openQuestions"]
    )
}
