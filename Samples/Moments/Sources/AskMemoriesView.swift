import SwiftUI
import AIKit

struct AskMemoriesView: View {
    @Bindable var store: MomentStore
    let backend: any AIBackend

    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var citations: [Moment] = []
    @State private var isThinking = false
    @State private var error: String?

    var body: some View {
        VStack {
            Text("Ask your memories")
                .font(.largeTitle).bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Text("E.g. “Where did I go last weekend?”, “Any happy moments involving coffee?”")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            HStack {
                TextField("Ask anything about your life", text: $question, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await ask() } }
                Button("Ask") { Task { await ask() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isThinking || question.isEmpty)
            }
            .padding()

            if isThinking {
                ProgressView("Thinking…")
            }

            if let error {
                Text(error).foregroundStyle(.red).padding()
            }

            if !answer.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(answer).padding()
                        if !citations.isEmpty {
                            Divider()
                            Text("Moments referenced").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                            ForEach(citations) { moment in
                                NavigationLink {
                                    DetailView(store: store, backend: backend, momentId: moment.id)
                                } label: {
                                    MomentRow(store: store, moment: moment)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                Spacer()
            }
        }
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ask() async {
        guard !question.isEmpty else { return }
        isThinking = true
        defer { isThinking = false }
        error = nil
        answer = ""
        do {
            let hits = try await store.search(question, limit: 6)
            citations = hits
            guard !hits.isEmpty else {
                answer = "I don't have any matching moments yet."
                return
            }
            let context = hits.enumerated().map { idx, m in
                "[\(idx + 1)] \(m.title) — \(m.createdAt.formatted(date: .abbreviated, time: .omitted))\n\(m.narrative)"
            }.joined(separator: "\n\n")
            let prompt = """
            Question: \(question)

            Relevant moments:
            \(context)

            Answer warmly in 2-4 sentences. Reference the moments by number when helpful.
            """
            answer = try await AIKit.chat(prompt, backend: backend, systemPrompt: "You are a friendly companion who helps someone reflect on their own life memories.")
        } catch {
            self.error = error.localizedDescription
        }
    }
}
