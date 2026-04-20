import SwiftUI
import AIKit
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AICameraAssistantView: View {
    public let backend: any AIBackend
    public var instructions: String = "Describe what the user captured."

    @State private var attachment: ImageAttachment?
    @State private var analysis: String = ""
    @State private var isAnalyzing = false
    @State private var error: String?
    #if canImport(PhotosUI)
    @State private var pickerItem: PhotosPickerItem?
    #endif

    public init(backend: any AIBackend, instructions: String = "Describe what the user captured.") {
        self.backend = backend
        self.instructions = instructions
    }

    public var body: some View {
        VStack(spacing: 16) {
            #if canImport(PhotosUI)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose photo", systemImage: "camera")
            }
            .onChange(of: pickerItem) { _, new in
                Task { await load(item: new) }
            }
            #endif

            if attachment != nil {
                Button(isAnalyzing ? "Analyzing…" : "Analyze") { Task { await analyze() } }
                    .disabled(isAnalyzing)
                    .buttonStyle(.borderedProminent)
            }

            if !analysis.isEmpty {
                ScrollView { Text(analysis).padding() }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .padding()
    }

    #if canImport(PhotosUI)
    private func load(item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            attachment = ImageAttachment(source: .data(data))
        }
    }
    #endif

    private func analyze() async {
        guard let attachment else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        analysis = ""
        error = nil
        do {
            let message = Message.user(instructions, attachments: [.image(attachment)])
            for try await chunk in backend.stream(messages: [message], tools: [], config: .default) {
                analysis += chunk.delta
                if chunk.finished { break }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
