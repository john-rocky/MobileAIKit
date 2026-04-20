import SwiftUI
import AIKit
import AIKitSpeech

struct SummaryView: View {
    let meeting: Meeting
    @State private var tts = TextToSpeech()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCard
                list("Decisions", items: meeting.decisions, icon: "checkmark.seal")
                actionItemsCard
                list("Risks", items: meeting.risks, icon: "exclamationmark.triangle")
                list("Open questions", items: meeting.openQuestions, icon: "questionmark.circle")
                transcriptCard
            }
            .padding()
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await tts.speakUtterance(meeting.spokenSummary) }
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
            }
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meeting.title).font(.largeTitle).bold()
            Text("\(meeting.startedAt.formatted()) · \(Int(meeting.durationSeconds / 60))m \(Int(meeting.durationSeconds) % 60)s")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Summary", systemImage: "text.alignleft").font(.headline)
                Spacer()
                Button {
                    Task { await tts.speakUtterance(meeting.summary) }
                } label: { Image(systemName: "speaker.wave.2.fill") }
            }
            Text(meeting.summary)
        }
        .padding().background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    func list(_ title: String, items: [String], icon: String) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(title, systemImage: icon).font(.headline)
                        Spacer()
                        Button {
                            Task { await tts.speakUtterance(title + ". " + items.joined(separator: ". ")) }
                        } label: { Image(systemName: "speaker.wave.2.fill") }
                    }
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top) {
                            Text("•").foregroundStyle(.secondary)
                            Text(item)
                        }
                    }
                }
                .padding().background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    var actionItemsCard: some View {
        Group {
            if !meeting.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Action items", systemImage: "checklist").font(.headline)
                        Spacer()
                        Button {
                            let text = meeting.actionItems.map {
                                "\($0.owner ?? "Unassigned"): \($0.task)" + ($0.due.map { " (due \($0))" } ?? "")
                            }.joined(separator: ". ")
                            Task { await tts.speakUtterance("Action items. " + text) }
                        } label: { Image(systemName: "speaker.wave.2.fill") }
                    }
                    ForEach(meeting.actionItems) { item in
                        HStack {
                            Text(item.owner ?? "?").bold().frame(width: 80, alignment: .leading)
                            VStack(alignment: .leading) {
                                Text(item.task)
                                if let due = item.due {
                                    Text("Due \(due)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding().background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    var transcriptCard: some View {
        DisclosureGroup("Transcript") {
            Text(meeting.transcript).font(.callout).padding(.vertical, 8)
        }
        .padding().background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
