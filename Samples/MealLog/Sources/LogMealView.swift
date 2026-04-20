import SwiftUI
import AIKit
import AIKitSpeech
import PhotosUI

@MainActor
struct LogMealView: View {
    @Bindable var store: MealStore
    let backend: any AIBackend

    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var note: String = ""
    @State private var processing = false
    @State private var error: String?
    @State private var lastMeal: Meal?
    @State private var tts = TextToSpeech()

    var body: some View {
        Form {
            Section("Photo") {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(imageData == nil ? "Snap your meal" : "Replace photo", systemImage: "camera.fill")
                }
                .onChange(of: pickerItem) { _, new in Task { await load(new) } }
                if let imageData, let ui = UIImage(data: imageData) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            Section("Optional note") {
                TextField("e.g. large portion, ate out, shared with friend", text: $note, axis: .vertical).lineLimit(1...4)
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            if let lastMeal {
                Section("Last logged") {
                    Text("\(lastMeal.kind.emoji) \(lastMeal.title)")
                    Text("\(lastMeal.estimatedCalories) kcal · P \(Int(lastMeal.proteinGrams))g · C \(Int(lastMeal.carbsGrams))g · F \(Int(lastMeal.fatGrams))g")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        Task { await tts.speakUtterance(lastMeal.spokenSummary) }
                    } label: {
                        Label("Read aloud", systemImage: "speaker.wave.2.fill")
                    }
                }
            }
            Section {
                Button {
                    Task { await save() }
                } label: {
                    if processing {
                        HStack { ProgressView(); Text("Analysing with Gemma 4…") }
                    } else {
                        Label("Log meal", systemImage: "checkmark.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(processing || imageData == nil)
            }
        }
        .navigationTitle("Log a meal")
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            self.imageData = data
        }
    }

    private func save() async {
        guard let imageData else { return }
        processing = true
        defer { processing = false }
        error = nil
        do {
            let prompt = """
            Identify the dishes in this photo and estimate nutrition.
            User's additional note: "\(note)"
            Produce JSON matching the schema.
            """
            let attachment = ImageAttachment(source: .data(imageData), mimeType: "image/jpeg")
            let messages: [Message] = [
                .system(StructuredRequest(type: MealExtraction.self, schema: MealExtraction.schema, instruction: "Return JSON matching the schema.").systemPrompt()),
                .user(prompt, attachments: [.image(attachment)])
            ]
            var config = GenerationConfig.deterministic
            config.maxTokens = 600
            let result = try await backend.generate(messages: messages, tools: [], config: config)
            let extraction = try StructuredDecoder().decode(MealExtraction.self, from: result.message.content)
            let kind = Meal.Kind(rawValue: extraction.kind) ?? .snack

            let imgName = "\(UUID().uuidString).jpg"
            try imageData.write(to: store.mediaDir.appendingPathComponent(imgName))

            let meal = Meal(
                kind: kind,
                title: extraction.title,
                description: extraction.description,
                dishes: extraction.dishes,
                estimatedCalories: extraction.estimatedCalories,
                proteinGrams: extraction.proteinGrams,
                carbsGrams: extraction.carbsGrams,
                fatGrams: extraction.fatGrams,
                dietaryFlags: extraction.dietaryFlags,
                imageFileName: imgName
            )
            try await store.add(meal)
            lastMeal = meal
            await tts.speakUtterance(meal.spokenSummary)

            pickerItem = nil
            self.imageData = nil
            note = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}
