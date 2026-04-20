import SwiftUI
import AIKit
import AIKitUI
import AIKitSpeech

struct VoiceDemoView: View {
    let backend: any AIBackend

    @State private var assistant: VoiceAssistant?
    @State private var error: String?

    var body: some View {
        Group {
            if let assistant {
                AIVoiceAssistantView(assistant: assistant)
            } else if let error {
                Text("Error: \(error)").foregroundStyle(.red).padding()
            } else {
                ProgressView("Preparing…")
                    .task { prepare() }
            }
        }
        .navigationTitle("Voice Assistant")
    }

    private func prepare() {
        do {
            self.assistant = try VoiceAssistant(
                backend: backend,
                locale: Locale(identifier: "en-US"),
                systemPrompt: "Reply in under 30 words."
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}
