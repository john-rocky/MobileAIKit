import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIPromptDiffView: View {
    public let a: String
    public let b: String
    public let labelA: String
    public let labelB: String

    public init(a: String, b: String, labelA: String = "A", labelB: String = "B") {
        self.a = a
        self.b = b
        self.labelA = labelA
        self.labelB = labelB
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(title: labelA, text: a, other: b)
            Divider()
            column(title: labelB, text: b, other: a)
        }
        .padding()
    }

    private func column(title: String, text: String, other: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(makeAttributed(text: text, other: other))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func makeAttributed(text: String, other: String) -> AttributedString {
        var result = AttributedString(text)
        let theseTokens = tokens(of: text)
        let otherTokens = Set(tokens(of: other))
        var cursor = text.startIndex
        for t in theseTokens {
            if let range = text.range(of: t, range: cursor..<text.endIndex) {
                cursor = range.upperBound
                if let attrRange = Range<AttributedString.Index>(range, in: result) {
                    if !otherTokens.contains(t) {
                        result[attrRange].backgroundColor = .yellow.opacity(0.4)
                    }
                }
            }
        }
        return result
    }

    private func tokens(of s: String) -> [String] {
        s.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIAnswerCompareView: View {
    public let backend: any AIBackend
    public let promptA: String
    public let promptB: String
    public let systemPrompt: String?

    @State private var answerA: String = ""
    @State private var answerB: String = ""
    @State private var isRunning: Bool = false

    public init(backend: any AIBackend, promptA: String, promptB: String, systemPrompt: String? = nil) {
        self.backend = backend
        self.promptA = promptA
        self.promptB = promptB
        self.systemPrompt = systemPrompt
    }

    public var body: some View {
        VStack(spacing: 12) {
            Button(isRunning ? "Running…" : "Compare") { Task { await run() } }
                .disabled(isRunning)
                .buttonStyle(.borderedProminent)
            AIPromptDiffView(a: answerA, b: answerB, labelA: "A", labelB: "B")
        }
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        async let a = AIKit.chat(promptA, backend: backend, systemPrompt: systemPrompt)
        async let b = AIKit.chat(promptB, backend: backend, systemPrompt: systemPrompt)
        do {
            answerA = try await a
            answerB = try await b
        } catch {
            answerA = "Error: \(error.localizedDescription)"
        }
    }
}
