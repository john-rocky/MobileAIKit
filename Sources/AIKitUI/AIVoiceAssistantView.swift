import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIVoiceAssistantView: View {
    @Bindable public var assistant: VoiceAssistant

    @State private var currentTranscript: String = ""
    @State private var currentAnswer: String = ""
    @State private var status: String = "Tap mic to start"
    @State private var isRunning: Bool = false
    @State private var task: Task<Void, Never>?

    public init(assistant: VoiceAssistant) {
        self.assistant = assistant
    }

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !currentTranscript.isEmpty {
                Text(currentTranscript).font(.body).padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            if !currentAnswer.isEmpty {
                ScrollView {
                    Text(currentAnswer).padding()
                }
            }
            Spacer()
            Button {
                toggle()
            } label: {
                Image(systemName: isRunning ? "stop.fill" : "mic.fill")
                    .font(.system(size: 44))
                    .frame(width: 96, height: 96)
                    .background(isRunning ? Color.red.opacity(0.25) : Color.accentColor.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    private func toggle() {
        if isRunning {
            task?.cancel()
            assistant.stop()
            isRunning = false
            return
        }
        isRunning = true
        currentTranscript = ""
        currentAnswer = ""
        status = "Listening…"
        task = Task { @MainActor in
            do {
                for try await event in assistant.run() {
                    switch event {
                    case .listening: status = "Listening…"
                    case .partialTranscript(let text):
                        currentTranscript = text
                    case .finalTranscript(let text):
                        currentTranscript = text
                    case .thinking: status = "Thinking…"
                    case .partialAnswer(let text): currentAnswer = text
                    case .finalAnswer(let text): currentAnswer = text
                    case .speaking: status = "Speaking…"
                    case .idle: status = "Ready"
                    case .error(let msg): status = "Error: \(msg)"
                    }
                }
            } catch {
                status = "Error: \(error.localizedDescription)"
            }
            isRunning = false
        }
    }
}
