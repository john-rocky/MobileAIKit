import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct MeetingSummarizerApp: App {
    private let backend = CoreMLLLMBackend(model: .gemma4e2b)
    @State private var storeResult: Result<MeetingStore, Error> = Result { try MeetingStore() }

    var body: some Scene {
        WindowGroup {
            CoreMLModelLoaderView(
                backend: backend,
                appName: "Meeting Summarizer",
                appIcon: "rectangle.3.group.bubble.left.fill"
            ) {
                switch storeResult {
                case .success(let store):
                    RootView(store: store, backend: backend)
                case .failure(let error):
                    StoreErrorView(message: error.localizedDescription) {
                        storeResult = Result { try MeetingStore() }
                    }
                }
            }
        }
    }
}

private struct StoreErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Couldn't open local store").font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry", action: retry).buttonStyle(.borderedProminent)
        }
        .padding()
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
