import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIComposerView: View {
    @Binding var text: String
    @Binding var attachments: [Attachment]
    let isGenerating: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    @State private var showPicker = false

    public init(
        text: Binding<String>,
        attachments: Binding<[Attachment]>,
        isGenerating: Bool,
        onSend: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._text = text
        self._attachments = attachments
        self.isGenerating = isGenerating
        self.onSend = onSend
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 8) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(attachments.indices, id: \.self) { idx in
                            HStack {
                                Image(systemName: icon(for: attachments[idx]))
                                Text(label(for: attachments[idx]))
                                    .font(.caption)
                                Button(role: .destructive) {
                                    attachments.remove(at: idx)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.secondary.opacity(0.12), in: Capsule())
                        }
                    }.padding(.horizontal)
                }
            }
            HStack(alignment: .bottom) {
                Button { showPicker = true } label: {
                    Image(systemName: "paperclip").font(.title3)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showPicker) {
                    AIAttachmentPicker(attachments: $attachments)
                }

                TextField("Ask anything…", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit(onSend)

                if isGenerating {
                    Button(role: .destructive, action: onCancel) {
                        Image(systemName: "stop.circle.fill").font(.title)
                    }.buttonStyle(.plain)
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill").font(.title)
                    }.buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
    }

    private func icon(for att: Attachment) -> String {
        switch att {
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .pdf: return "doc.richtext"
        case .text: return "doc.plaintext"
        case .file: return "doc"
        }
    }

    private func label(for att: Attachment) -> String {
        switch att {
        case .image: return "Image"
        case .audio: return "Audio"
        case .video: return "Video"
        case .pdf(let p): return p.fileURL.lastPathComponent
        case .text(let t): return t.title ?? "Text"
        case .file(let f): return f.fileURL.lastPathComponent
        }
    }
}
