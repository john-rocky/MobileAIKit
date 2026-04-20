import SwiftUI
import AIKit
import AIKitSpeech

@MainActor
struct RecordView: View {
    @Bindable var store: MeetingStore
    let backend: any AIBackend

    @State private var stt: SpeechToText?
    @State private var listening: Bool = false
    @State private var liveTask: Task<Void, Never>?
    @State private var transcript: String = ""
    @State private var startedAt: Date?
    @State private var error: String?
    @State private var finalising: Bool = false
    @State private var savedMeeting: Meeting?
    @State private var navigateToSummary: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            header
            transcriptView
            controls
        }
        .padding()
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToSummary) {
            if let m = savedMeeting { SummaryView(meeting: m) }
        }
    }

    var header: some View {
        HStack {
            if let startedAt, listening {
                TimelineView(.periodic(from: startedAt, by: 1)) { _ in
                    Text(elapsedString(from: startedAt)).monospacedDigit().font(.title2).bold()
                }
            } else {
                Text(listening ? "Listening…" : "Tap record to start").font(.title3)
            }
            Spacer()
        }
    }

    var transcriptView: some View {
        ScrollView {
            Text(transcript.isEmpty ? "(transcript will appear here)" : transcript)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                .padding()
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    var controls: some View {
        VStack(spacing: 8) {
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
            if finalising {
                ProgressView("Gemma 4 is summarising the meeting…")
            }
            HStack(spacing: 24) {
                Button {
                    listening ? stopAndSave() : start()
                } label: {
                    VStack {
                        Image(systemName: listening ? "stop.circle.fill" : "record.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.red)
                        Text(listening ? "Finish & summarise" : "Record")
                    }
                }
                .buttonStyle(.plain)
                .disabled(finalising)
            }
        }
    }

    private func elapsedString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        let m = seconds / 60, s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Mic

    private func start() {
        error = nil
        transcript = ""
        do {
            let s = try SpeechToText(locale: Locale.current)
            self.stt = s
            self.listening = true
            self.startedAt = Date()
            liveTask = Task {
                let granted = await s.requestAuthorization()
                guard granted else {
                    await MainActor.run { self.error = "Speech denied"; self.listening = false }
                    return
                }
                do {
                    for try await r in try s.liveRecognition() {
                        await MainActor.run { self.transcript = r.text }
                        if r.isFinal { break }
                    }
                } catch {
                    await MainActor.run { self.error = error.localizedDescription }
                }
            }
        } catch {
            self.error = error.localizedDescription
            self.listening = false
        }
    }

    private func stopAndSave() {
        stt?.stop()
        liveTask?.cancel()
        listening = false
        let finalTranscript = transcript
        let started = startedAt ?? Date()
        Task { await finalise(transcript: finalTranscript, startedAt: started) }
    }

    private func finalise(transcript: String, startedAt: Date) async {
        guard !transcript.isEmpty else { return }
        finalising = true
        defer { finalising = false }
        error = nil
        do {
            let extraction: MeetingExtraction = try await AIKit.extract(
                MeetingExtraction.self,
                from: transcript,
                schema: MeetingExtraction.schema,
                instruction: "Extract structured meeting minutes from the transcript.",
                backend: backend
            )
            let meeting = Meeting(
                startedAt: startedAt,
                durationSeconds: Date().timeIntervalSince(startedAt),
                title: extraction.title,
                transcript: transcript,
                summary: extraction.summary,
                decisions: extraction.decisions,
                actionItems: extraction.actionItems,
                risks: extraction.risks,
                openQuestions: extraction.openQuestions
            )
            try store.add(meeting)
            savedMeeting = meeting
            navigateToSummary = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
