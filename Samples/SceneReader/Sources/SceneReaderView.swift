import SwiftUI
import AIKit
import AIKitVision
import AIKitSpeech
import PhotosUI
import AVFoundation

@MainActor
struct SceneReaderView: View {
    let backend: any AIBackend

    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var ocrText: String = ""
    @State private var sceneDescription: String = ""
    @State private var processing: Bool = false
    @State private var error: String?
    @State private var followUpQuestion: String = ""
    @State private var followUpAnswer: String = ""
    @State private var stt: SpeechToText?
    @State private var listening: Bool = false
    @State private var liveTask: Task<Void, Never>?
    @State private var tts = TextToSpeech(rate: AVSpeechUtteranceDefaultSpeechRate * 0.95)
    @State private var speakingAll: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                pickerButtons
                if let imageData, let ui = UIImage(data: imageData) {
                    Image(uiImage: ui).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                }
                if processing { ProgressView("Reading the scene…") }
                if let error { Text(error).foregroundStyle(.red) }
                if !sceneDescription.isEmpty { descriptionCard }
                if !ocrText.isEmpty { ocrCard }
                if !sceneDescription.isEmpty { followUpSection }
            }
            .padding()
        }
        .navigationTitle("Scene reader")
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SceneReader").font(.largeTitle).bold()
            Text("Point, tap, listen. Gemma 4 narrates what the camera sees.")
                .foregroundStyle(.secondary)
        }
    }

    var pickerButtons: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Pick photo", systemImage: "photo.stack")
                    .frame(maxWidth: .infinity).padding()
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            }
            .onChange(of: pickerItem) { _, new in Task { await load(new) } }
        }
    }

    var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Scene", systemImage: "sparkles").font(.headline)
                Spacer()
                Button {
                    Task { await readAloud() }
                } label: {
                    Label(speakingAll ? "Stop" : "Read aloud", systemImage: speakingAll ? "stop.circle.fill" : "play.circle.fill")
                }.buttonStyle(.bordered)
            }
            Text(sceneDescription)
        }
        .padding().background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    var ocrCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Detected text", systemImage: "text.viewfinder").font(.headline)
                Spacer()
                Button {
                    Task { await tts.speakUtterance(ocrText) }
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
            }
            Text(ocrText).monospaced().font(.callout)
        }
        .padding().background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    var followUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask a follow-up").font(.headline)
            HStack {
                TextField("e.g. どこに座ればいい？", text: $followUpQuestion, axis: .vertical).lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                Button {
                    listening ? stopListening() : startListening()
                } label: {
                    Image(systemName: listening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2).foregroundStyle(listening ? .red : .tint)
                }
                Button("Ask") { Task { await askFollowUp() } }
                    .buttonStyle(.borderedProminent).disabled(followUpQuestion.isEmpty || processing)
            }
            if !followUpAnswer.isEmpty {
                HStack {
                    Text(followUpAnswer).padding(8).background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Button {
                        Task { await tts.speakUtterance(followUpAnswer) }
                    } label: { Image(systemName: "speaker.wave.2.fill") }
                }
            }
        }
    }

    // MARK: - Actions

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        self.imageData = data
        self.ocrText = ""
        self.sceneDescription = ""
        self.followUpAnswer = ""
        await analyze()
    }

    private func analyze() async {
        guard let imageData else { return }
        processing = true
        defer { processing = false }
        error = nil
        do {
            let attachment = ImageAttachment(source: .data(imageData), mimeType: "image/jpeg")

            async let ocr = AIKit.ocr(image: attachment, languages: ["en-US", "ja-JP"])
            async let description = AIKit.analyzeImage(
                attachment,
                prompt: "Narrate this scene for someone who cannot see it. Focus on layout, people, objects, signage, colours, and any text. Be specific and practical.",
                backend: backend
            )
            let r1 = try await ocr
            let r2 = try await description
            self.ocrText = r1.text
            self.sceneDescription = r2

            await tts.speakUtterance(r2)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func readAloud() async {
        if speakingAll {
            tts.stop()
            speakingAll = false
            return
        }
        speakingAll = true
        let parts: [String] = [sceneDescription, ocrText.isEmpty ? nil : "Detected text. \(ocrText)"].compactMap { $0 }
        for part in parts {
            if !speakingAll { break }
            await tts.speakUtterance(part)
        }
        speakingAll = false
    }

    private func askFollowUp() async {
        guard let imageData, !followUpQuestion.isEmpty else { return }
        processing = true
        defer { processing = false }
        error = nil
        do {
            let attachment = ImageAttachment(source: .data(imageData), mimeType: "image/jpeg")
            let answer = try await AIKit.analyzeImage(
                attachment,
                prompt: followUpQuestion + "\n\nContext (already known): " + sceneDescription,
                backend: backend
            )
            followUpAnswer = answer
            await tts.speakUtterance(answer)
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
            liveTask = Task {
                let granted = await s.requestAuthorization()
                guard granted else {
                    await MainActor.run { self.error = "Speech denied"; self.listening = false }
                    return
                }
                do {
                    for try await r in try s.liveRecognition() {
                        await MainActor.run { self.followUpQuestion = r.text }
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
