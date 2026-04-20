import SwiftUI
import AIKit
import AIKitIntegration

struct BrowseAndAskView: View {
    let backend: any AIBackend

    @State private var question: String = "What is MobileAIKit?"
    @State private var answer: String = ""
    @State private var isRunning = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Question", text: $question).textFieldStyle(.roundedBorder).onSubmit(run)
                Button(isRunning ? "…" : "Ask") { run() }
                    .disabled(isRunning || question.isEmpty)
                    .buttonStyle(.borderedProminent)
            }.padding(.horizontal)

            if isRunning { ProgressView() }
            if let error { Text(error).foregroundStyle(.red) }
            ScrollView { Text(answer).padding() }
        }
        .navigationTitle("Browse & Ask")
    }

    private func run() {
        Task {
            isRunning = true
            defer { isRunning = false }
            error = nil
            do {
                answer = try await AIKit.browseAndAsk(question, backend: backend, maxPages: 2)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
