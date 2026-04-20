import SwiftUI
import AIKit
import UniformTypeIdentifiers

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIAttachmentDropZone<Label: View>: View {
    @Binding public var attachments: [Attachment]
    public let label: () -> Label

    @State private var isTargeted = false

    public init(attachments: Binding<[Attachment]>, @ViewBuilder label: @escaping () -> Label) {
        self._attachments = attachments
        self.label = label
    }

    public var body: some View {
        label()
            .padding()
            .background(isTargeted ? .tint.opacity(0.15) : .secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .dropDestination(for: URL.self) { urls, _ in
                for url in urls {
                    let type = UTType(filenameExtension: url.pathExtension) ?? .data
                    if type.conforms(to: .image) {
                        attachments.append(.image(ImageAttachment(source: .fileURL(url))))
                    } else if type.conforms(to: .audio) {
                        attachments.append(.audio(AudioAttachment(source: .fileURL(url))))
                    } else if type.conforms(to: .movie) {
                        attachments.append(.video(VideoAttachment(fileURL: url)))
                    } else if type.conforms(to: .pdf) {
                        attachments.append(.pdf(PDFAttachment(fileURL: url)))
                    } else {
                        attachments.append(.file(FileAttachment(fileURL: url)))
                    }
                }
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}
