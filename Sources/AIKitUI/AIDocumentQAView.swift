import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIDocumentQAView: View {
    public let backend: any AIBackend
    public let index: VectorIndex

    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var citations: [RetrievedDocument] = []
    @State private var isAsking: Bool = false
    @State private var error: String?

    public init(backend: any AIBackend, index: VectorIndex) {
        self.backend = backend
        self.index = index
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Ask the documents…", text: $question)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(ask)
                Button("Ask", action: ask)
                    .disabled(isAsking || question.isEmpty)
                    .buttonStyle(.borderedProminent)
            }.padding(.horizontal)

            if isAsking {
                ProgressView()
            }

            if !answer.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(answer).textSelection(.enabled)
                        if !citations.isEmpty {
                            Divider()
                            Text("Sources").font(.headline)
                            ForEach(citations, id: \.chunk.id) { doc in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(doc.source).font(.caption).foregroundStyle(.secondary)
                                    Text(doc.text).font(.caption).lineLimit(5)
                                }.padding(8).background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }.padding()
                }
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
            Spacer()
        }
    }

    private func ask() {
        guard !question.isEmpty else { return }
        isAsking = true
        answer = ""
        citations = []
        error = nil
        Task {
            do {
                let docs = try await index.search(query: question, limit: 6)
                citations = docs
                let context = docs.map { "[\($0.source)] \($0.text)" }.joined(separator: "\n---\n")
                let system = "Answer concisely using only the provided context. If unknown, say 'I don't know'."
                let prompt = "Question: \(question)\n\nContext:\n\(context)"
                let reply = try await AIKit.chat(prompt, backend: backend, systemPrompt: system)
                answer = reply
            } catch {
                self.error = error.localizedDescription
            }
            isAsking = false
        }
    }
}
