import SwiftUI
import AIKit
import AIKitSpeech
import AIKitIntegration
import PhotosUI
#if canImport(CoreLocation)
import CoreLocation
#endif

@MainActor
struct CaptureView: View {
    @Bindable var store: MomentStore
    let backend: any AIBackend

    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var transcriber: SpeechToText?
    @State private var transcribing = false
    @State private var transcript: String = ""
    @State private var live: Task<Void, Never>?
    @State private var processing = false
    @State private var error: String?
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var placeName: String?
    @State private var locationBridge = LocationBridge()

    var body: some View {
        Form {
            Section("Photo") {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(imageData == nil ? "Choose a photo" : "Replace photo", systemImage: "photo.stack")
                }
                .onChange(of: pickerItem) { _, new in
                    Task { await loadPhoto(new) }
                }
                if let imageData, let ui = UIImage(data: imageData) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            Section("Voice note") {
                Button {
                    transcribing ? stopListening() : startListening()
                } label: {
                    Label(transcribing ? "Stop" : "Tap and speak", systemImage: transcribing ? "stop.circle.fill" : "mic.circle.fill")
                        .foregroundStyle(transcribing ? .red : .tint)
                }
                if !transcript.isEmpty {
                    Text(transcript).font(.body)
                }
            }

            Section("Location") {
                if let placeName {
                    Text(placeName)
                } else if let latitude, let longitude {
                    Text("\(latitude), \(longitude)")
                } else {
                    Text("Not captured").foregroundStyle(.secondary)
                }
                Button("Capture current location") { Task { await captureLocation() } }
            }

            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if processing {
                        HStack { ProgressView(); Text("Gemma 4 is writing…") }
                    } else {
                        Label("Save moment", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(processing || imageData == nil)
            }
        }
        .navigationTitle("New Moment")
    }

    // MARK: - Photo

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                self.imageData = data
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Voice

    private func startListening() {
        error = nil
        do {
            let stt = try SpeechToText(locale: Locale.current)
            self.transcriber = stt
            transcribing = true
            transcript = ""
            live = Task {
                let granted = await stt.requestAuthorization()
                guard granted else {
                    await MainActor.run { self.error = "Speech recognition denied" }
                    return
                }
                do {
                    for try await r in try stt.liveRecognition() {
                        await MainActor.run { self.transcript = r.text }
                        if r.isFinal { break }
                    }
                } catch {
                    await MainActor.run { self.error = error.localizedDescription }
                }
                await MainActor.run { self.transcribing = false }
            }
        } catch {
            self.error = error.localizedDescription
            self.transcribing = false
        }
    }

    private func stopListening() {
        transcriber?.stop()
        live?.cancel()
        transcribing = false
    }

    // MARK: - Location

    private func captureLocation() async {
        _ = await locationBridge.requestWhenInUseAuthorization()
        do {
            let loc = try await locationBridge.currentLocation()
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
            #if canImport(CoreLocation)
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(loc)
            placeName = placemarks?.first?.locality ?? placemarks?.first?.name
            #endif
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Save

    private func save() async {
        guard let imageData else { return }
        processing = true
        defer { processing = false }
        error = nil
        do {
            let transcriptCopy = transcript
            let prompt = """
            Describe the attached photo. The user spoke this voice note: "\(transcriptCopy)"
            Weave the visual content and the voice note into a single moment.
            """
            let attachment = ImageAttachment(source: .data(imageData), mimeType: "image/jpeg")
            let message = Message.user(prompt, attachments: [.image(attachment)])

            let extraction: MomentExtraction = try await extract(message: message)

            let imageName = "\(UUID().uuidString).jpg"
            try imageData.write(to: store.mediaDirectory.appendingPathComponent(imageName))

            let moment = Moment(
                title: extraction.title,
                narrative: extraction.narrative,
                tags: extraction.tags,
                rows: extraction.rows,
                latitude: latitude,
                longitude: longitude,
                placeName: placeName,
                mood: extraction.mood,
                imageFileName: imageName,
                audioTranscript: transcriptCopy.isEmpty ? nil : transcriptCopy
            )
            try await store.add(moment)

            // Reset form
            pickerItem = nil
            self.imageData = nil
            transcript = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func extract(message: Message) async throws -> MomentExtraction {
        let request = StructuredRequest(
            type: MomentExtraction.self,
            schema: MomentExtraction.schema,
            instruction: "Return JSON matching the schema describing this moment."
        )
        let messages: [Message] = [
            .system(request.systemPrompt()),
            message
        ]
        var config = GenerationConfig.deterministic
        config.maxTokens = 600
        let result = try await backend.generate(messages: messages, tools: [], config: config)
        return try StructuredDecoder().decode(MomentExtraction.self, from: result.message.content)
    }
}
