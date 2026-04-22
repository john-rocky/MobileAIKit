import SwiftUI
import AIKit
import AIKitSpeech

@MainActor
struct AskView: View {
    @Bindable var store: MealStore
    let backend: any AIBackend

    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isAsking: Bool = false
    @State private var error: String?
    @State private var tts = TextToSpeech()
    @State private var stt: SpeechToText?
    @State private var listening = false
    @State private var liveTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ask your meal log").font(.largeTitle).bold()
                Text("“How many calories yesterday?”, “What high-protein meals did I have this week?”")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)

            HStack {
                TextField("Ask anything", text: $question, axis: .vertical).lineLimit(1...3)
                    .textFieldStyle(.roundedBorder).onSubmit { Task { await ask() } }
                Button {
                    listening ? stopListening() : startListening()
                } label: {
                    Image(systemName: listening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2).foregroundStyle(listening ? Color.red : Color.accentColor)
                }
                Button("Ask") { Task { await ask() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAsking || question.isEmpty)
            }
            .padding(.horizontal)

            if let error { Text(error).foregroundStyle(.red) }
            if isAsking { ProgressView("Thinking…") }

            if !answer.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(answer).padding()
                        HStack {
                            Spacer()
                            Button {
                                Task { await tts.speakUtterance(answer) }
                            } label: {
                                Label("Read aloud", systemImage: "speaker.wave.2.fill")
                            }.buttonStyle(.bordered)
                        }.padding(.horizontal)
                    }
                }
            } else {
                Spacer()
            }
        }
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ask() async {
        guard !question.isEmpty else { return }
        isAsking = true
        defer { isAsking = false }
        error = nil; answer = ""
        do {
            let hits = try await store.search(question, limit: 8)
            let context: String
            if hits.isEmpty {
                context = "(no matching meals)"
            } else {
                context = hits.map { m in
                    "- \(m.date.formatted()): \(m.kind.emoji) \(m.title) — \(m.estimatedCalories) kcal, P\(Int(m.proteinGrams))g C\(Int(m.carbsGrams))g F\(Int(m.fatGrams))g"
                }.joined(separator: "\n")
            }
            let prompt = """
            User question: \(question)

            Matching meals from the log:
            \(context)

            Give a short, helpful answer based only on the meals above. Use numbers where relevant.
            """
            let result = try await AIKit.chat(
                prompt, backend: backend,
                systemPrompt: "You are a friendly nutrition assistant reading the user's own meal log."
            )
            answer = result
            await tts.speakUtterance(result)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startListening() {
        error = nil
        do {
            let s = try SpeechToText(locale: Locale.current)
            self.stt = s
            self.listening = true
            self.liveTask = Task {
                let granted = await s.requestAuthorization()
                guard granted else {
                    await MainActor.run { self.error = "Speech denied"; self.listening = false }
                    return
                }
                do {
                    for try await r in try s.liveRecognition() {
                        await MainActor.run { self.question = r.text }
                        if r.isFinal { break }
                    }
                } catch {
                    await MainActor.run { self.error = error.localizedDescription }
                }
                await MainActor.run { self.listening = false; self.stt = nil }
            }
        } catch {
            self.error = error.localizedDescription
            self.listening = false
        }
    }

    private func stopListening() {
        stt?.stop()
        liveTask?.cancel()
        listening = false
    }
}
