import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct MeetingSummarizerApp: App {
    @State private var backend: (any AIBackend)?
    @State private var store: MeetingStore?
    @State private var error: String?

    var body: some Scene {
        WindowGroup {
            if let backend, let store {
                RootView(store: store, backend: backend)
            } else if let error {
                VStack {
                    Text("Setup failed").font(.headline)
                    Text(error).foregroundStyle(.secondary).padding()
                    Button("Retry") { Task { await boot() } }.buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.3.group.bubble.left.fill").font(.system(size: 60)).foregroundStyle(.tint)
                    Text("Preparing Gemma 4…"); ProgressView()
                }.task { await boot() }
            }
        }
    }

    @MainActor
    private func boot() async {
        do {
            let s = try MeetingStore()
            let b = CoreMLLLMBackend(model: .gemma4e2b)
            try await b.load()
            self.store = s
            self.backend = b
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RootView: View {
    @Bindable var store: MeetingStore
    let backend: any AIBackend

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        RecordView(store: store, backend: backend)
                    } label: {
                        Label("Start a new meeting", systemImage: "record.circle.fill").foregroundStyle(.red)
                    }
                }
                if store.meetings.isEmpty {
                    ContentUnavailableView("No meetings yet", systemImage: "waveform")
                } else {
                    Section("History") {
                        ForEach(store.meetings) { meeting in
                            NavigationLink {
                                SummaryView(meeting: meeting)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meeting.title).font(.headline)
                                    Text(meeting.startedAt.formatted()).font(.caption).foregroundStyle(.secondary)
                                    Text(meeting.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet { try? store.delete(store.meetings[idx]) }
                        }
                    }
                }
            }
            .navigationTitle("Meetings")
        }
    }
}
