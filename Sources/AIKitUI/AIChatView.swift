import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIChatView: View {
    @Bindable private var session: ChatSession
    @State private var pendingText: String = ""
    @State private var pendingAttachments: [Attachment] = []
    @State private var streamingText: String = ""
    @State private var error: String?

    public init(session: ChatSession) {
        self.session = session
    }

    public var body: some View {
        VStack(spacing: 0) {
            AIMessageList(
                messages: session.messages,
                streamingText: streamingText
            )
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            Divider()
            AIComposerView(
                text: $pendingText,
                attachments: $pendingAttachments,
                isGenerating: session.isGenerating,
                onSend: send,
                onCancel: { session.cancel() }
            )
        }
    }

    private func send() {
        let text = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !session.isGenerating else { return }
        let attachments = pendingAttachments
        pendingText = ""
        pendingAttachments.removeAll()
        streamingText = ""
        error = nil

        Task {
            do {
                for try await chunk in session.sendStream(text, attachments: attachments) {
                    streamingText += chunk.delta
                }
                streamingText = ""
            } catch let AIError.cancelled {
                streamingText = ""
            } catch {
                self.error = error.localizedDescription
                streamingText = ""
            }
        }
    }
}
