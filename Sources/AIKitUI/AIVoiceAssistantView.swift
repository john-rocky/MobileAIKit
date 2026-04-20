import SwiftUI
import AIKit
#if canImport(AVFoundation)
import AVFoundation
#endif

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIVoiceAssistantView: View {
    @Bindable public var session: ChatSession
    public var onTranscribe: @Sendable (AudioAttachment) async throws -> String
    public var onSpeak: @Sendable (String) async -> Void

    @State private var isListening: Bool = false
    @State private var liveTranscript: String = ""
    @State private var error: String?

    public init(
        session: ChatSession,
        onTranscribe: @Sendable @escaping (AudioAttachment) async throws -> String,
        onSpeak: @Sendable @escaping (String) async -> Void
    ) {
        self.session = session
        self.onTranscribe = onTranscribe
        self.onSpeak = onSpeak
    }

    public var body: some View {
        VStack(spacing: 24) {
            AIMessageList(messages: session.messages)
            if !liveTranscript.isEmpty {
                Text(liveTranscript)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
            Button {
                isListening.toggle()
            } label: {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 48))
                    .padding()
                    .background(isListening ? .red.opacity(0.2) : .secondary.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .padding()
        }
    }
}
