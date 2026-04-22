import SwiftUI
import AIKit
import AIKitSpeech

@MainActor
struct InterpreterView: View {
    let backend: any AIBackend

    @State private var sideA: LanguagePair = LanguagePair.presets[0]
    @State private var sideB: LanguagePair = LanguagePair.presets[1]
    @State private var utterances: [Utterance] = []
    @State private var activeSpeaker: Speaker?
    @State private var liveText: String = ""
    @State private var error: String?
    @State private var session: Task<Void, Never>?
    @State private var autoSpeak: Bool = true
    @State private var tts = TextToSpeech()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pairPicker
                Divider()
                transcriptView
                Divider()
                controls
            }
            .navigationTitle("Interpreter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $autoSpeak) { Image(systemName: "speaker.wave.2.fill") }
                        .toggleStyle(.button)
                }
            }
        }
    }

    var pairPicker: some View {
        HStack {
            languageMenu(title: "A", selection: $sideA)
            Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
            languageMenu(title: "B", selection: $sideB)
        }.padding()
    }

    func languageMenu(title: String, selection: Binding<LanguagePair>) -> some View {
        Menu {
            ForEach(LanguagePair.presets, id: \.locale.identifier) { pair in
                Button(pair.displayName) { selection.wrappedValue = pair }
            }
        } label: {
            VStack(spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(selection.wrappedValue.displayName).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(utterances) { u in
                        UtteranceBubble(utterance: u, onSpeak: { speak(u) })
                            .id(u.id)
                    }
                    if !liveText.isEmpty, let speaker = activeSpeaker {
                        UtteranceBubble(
                            utterance: Utterance(
                                speaker: speaker,
                                sourceLocale: pair(for: speaker).locale.identifier,
                                targetLocale: partner(of: speaker).locale.identifier,
                                original: liveText,
                                translation: "…"
                            ),
                            onSpeak: nil
                        )
                        .id("live")
                        .opacity(0.6)
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                .padding()
            }
            .onChange(of: utterances.count) { _, _ in
                if let last = utterances.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    var controls: some View {
        HStack(spacing: 30) {
            micButton(for: .a, label: sideA.displayName)
            micButton(for: .b, label: sideB.displayName)
        }
        .padding()
    }

    func micButton(for side: Speaker, label: String) -> some View {
        let active = activeSpeaker == side
        return Button { toggle(side) } label: {
            VStack {
                Image(systemName: active ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(active ? Color.red : Color.accentColor)
                Text(label).font(.caption)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    func pair(for speaker: Speaker) -> LanguagePair {
        speaker == .a ? sideA : sideB
    }

    func partner(of speaker: Speaker) -> LanguagePair {
        speaker == .a ? sideB : sideA
    }

    func toggle(_ speaker: Speaker) {
        if activeSpeaker == speaker {
            session?.cancel()
            activeSpeaker = nil
            return
        }
        session?.cancel()
        activeSpeaker = speaker
        liveText = ""
        session = Task { await listenAndTranslate(for: speaker) }
    }

    func listenAndTranslate(for speaker: Speaker) async {
        let sourcePair = pair(for: speaker)
        let targetPair = partner(of: speaker)
        do {
            let stt = try SpeechToText(locale: sourcePair.locale)
            guard await stt.requestAuthorization() else {
                await MainActor.run { self.error = "Speech denied" }
                return
            }
            var final: String?
            for try await r in try stt.liveRecognition() {
                if Task.isCancelled { break }
                await MainActor.run { self.liveText = r.text }
                if r.isFinal { final = r.text; break }
            }
            stt.stop()

            guard let text = final, !text.isEmpty else {
                await MainActor.run {
                    self.liveText = ""
                    self.activeSpeaker = nil
                }
                return
            }

            let translation = try await translate(text, from: sourcePair, to: targetPair)
            let utterance = Utterance(
                speaker: speaker,
                sourceLocale: sourcePair.locale.identifier,
                targetLocale: targetPair.locale.identifier,
                original: text,
                translation: translation
            )
            await MainActor.run {
                self.utterances.append(utterance)
                self.liveText = ""
                self.activeSpeaker = nil
                if self.autoSpeak { self.speak(utterance) }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.activeSpeaker = nil
                self.liveText = ""
            }
        }
    }

    func translate(_ text: String, from source: LanguagePair, to target: LanguagePair) async throws -> String {
        try await AIKit.translate(text, to: target.displayName, backend: backend)
    }

    func speak(_ u: Utterance) {
        let locale = Locale(identifier: u.targetLocale)
        Task { await tts.speakUtterance(u.translation, locale: locale) }
    }
}

struct UtteranceBubble: View {
    let utterance: Utterance
    var onSpeak: (() -> Void)?

    var body: some View {
        HStack {
            if utterance.speaker == .b { Spacer() }
            VStack(alignment: utterance.speaker == .a ? .leading : .trailing, spacing: 4) {
                Text(utterance.speaker.rawValue).font(.caption2).foregroundStyle(.secondary)
                Text(utterance.original).font(.callout).foregroundStyle(.secondary)
                Text(utterance.translation).font(.body)
                if let onSpeak {
                    Button {
                        onSpeak()
                    } label: {
                        Label("Play", systemImage: "speaker.wave.2.fill")
                            .font(.caption)
                    }
                }
            }
            .padding(10)
            .background(utterance.speaker == .a ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.secondary.opacity(0.15)), in: RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: 320, alignment: utterance.speaker == .a ? .leading : .trailing)
            if utterance.speaker == .a { Spacer() }
        }
    }
}
