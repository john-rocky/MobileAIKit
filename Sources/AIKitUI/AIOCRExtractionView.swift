import SwiftUI
import AIKit
#if canImport(AIKitVision)
import AIKitVision
#endif

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIOCRExtractionView: View {
    @Binding public var attachments: [Attachment]
    @State private var result: String = ""
    @State private var regionCount: Int = 0
    @State private var error: String?
    @State private var isRecognizing = false

    public init(attachments: Binding<[Attachment]>) {
        self._attachments = attachments
    }

    public var body: some View {
        VStack(spacing: 16) {
            if attachments.isEmpty {
                Text("Add an image to extract text.").foregroundStyle(.secondary)
            }
            ForEach(attachments.indices, id: \.self) { idx in
                if case .image = attachments[idx] {
                    Text("Image #\(idx + 1)").font(.caption).foregroundStyle(.secondary)
                }
            }
            if isRecognizing { ProgressView() }
            if !result.isEmpty {
                ScrollView {
                    Text(result).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Button("Recognize") { Task { await recognize() } }
                .buttonStyle(.borderedProminent)
                .disabled(isRecognizing || attachments.isEmpty)
        }
        .padding()
    }

    private func recognize() async {
        #if canImport(AIKitVision)
        isRecognizing = true
        defer { isRecognizing = false }
        do {
            var allText = ""
            var count = 0
            for att in attachments {
                if case .image(let img) = att {
                    let r = try await OCR.recognize(in: img)
                    if !allText.isEmpty { allText += "\n\n---\n\n" }
                    allText += r.text
                    count += r.regions.count
                }
            }
            result = allText
            regionCount = count
        } catch {
            self.error = error.localizedDescription
        }
        #else
        error = "AIKitVision module not available"
        #endif
    }
}
