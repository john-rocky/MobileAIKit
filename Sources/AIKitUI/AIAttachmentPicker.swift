import SwiftUI
import AIKit
#if canImport(PhotosUI)
import PhotosUI
#endif
import UniformTypeIdentifiers

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIAttachmentPicker: View {
    @Binding var attachments: [Attachment]
    @Environment(\.dismiss) private var dismiss

    #if canImport(PhotosUI)
    @State private var photoSelection: [PhotosPickerItem] = []
    #endif
    @State private var showFiles = false
    @State private var errorMessage: String?

    public init(attachments: Binding<[Attachment]>) {
        self._attachments = attachments
    }

    public var body: some View {
        NavigationStack {
            List {
                #if canImport(PhotosUI)
                Section("Photos") {
                    PhotosPicker(
                        selection: $photoSelection,
                        maxSelectionCount: 8,
                        matching: .any(of: [.images])
                    ) {
                        Label("Choose photos", systemImage: "photo.stack")
                    }
                    .onChange(of: photoSelection) { _, newValue in
                        Task { await loadPhotos(items: newValue) }
                    }
                }
                #endif

                Section("Files") {
                    Button { showFiles = true } label: {
                        Label("Import file", systemImage: "folder")
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .fileImporter(
                isPresented: $showFiles,
                allowedContentTypes: [.image, .pdf, .audio, .movie, .plainText, .data],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls { attachments.append(attachment(for: url)) }
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .navigationTitle("Add attachment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    #if canImport(PhotosUI)
    private func loadPhotos(items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                attachments.append(.image(ImageAttachment(source: .data(data), mimeType: "image/jpeg")))
            }
        }
        photoSelection.removeAll()
        dismiss()
    }
    #endif

    private func attachment(for url: URL) -> Attachment {
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        if type.conforms(to: .image) {
            return .image(ImageAttachment(source: .fileURL(url), mimeType: type.preferredMIMEType ?? "image/png"))
        }
        if type.conforms(to: .audio) {
            return .audio(AudioAttachment(source: .fileURL(url), mimeType: type.preferredMIMEType ?? "audio/wav"))
        }
        if type.conforms(to: .movie) {
            return .video(VideoAttachment(fileURL: url, mimeType: type.preferredMIMEType ?? "video/mp4"))
        }
        if type.conforms(to: .pdf) {
            return .pdf(PDFAttachment(fileURL: url))
        }
        if type.conforms(to: .plainText) {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return .text(TextAttachment(text: text, title: url.lastPathComponent))
        }
        return .file(FileAttachment(fileURL: url, mimeType: type.preferredMIMEType ?? "application/octet-stream"))
    }
}
