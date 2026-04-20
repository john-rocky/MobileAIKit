import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIPromptPlaygroundView: View {
    public let backend: any AIBackend

    @State private var systemPrompt: String = "You are a helpful assistant."
    @State private var userPrompt: String = ""
    @State private var output: String = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Double = 512
    @State private var error: String?
    @State private var isRunning: Bool = false

    public init(backend: any AIBackend) { self.backend = backend }

    public var body: some View {
        Form {
            Section("System") {
                TextField("System prompt", text: $systemPrompt, axis: .vertical).lineLimit(2...8)
            }
            Section("User") {
                TextField("User prompt", text: $userPrompt, axis: .vertical).lineLimit(2...8)
            }
            Section("Parameters") {
                HStack {
                    Text("Temperature")
                    Slider(value: $temperature, in: 0...2)
                    Text(String(format: "%.2f", temperature)).monospacedDigit().frame(width: 50)
                }
                HStack {
                    Text("Max tokens")
                    Slider(value: $maxTokens, in: 16...2048, step: 16)
                    Text("\(Int(maxTokens))").monospacedDigit().frame(width: 60)
                }
            }
            Section("Output") {
                if let error { Text(error).foregroundStyle(.red) }
                Text(output).textSelection(.enabled).font(.body)
            }
            Section {
                Button(isRunning ? "Running…" : "Run") { Task { await run() } }
                    .disabled(isRunning || userPrompt.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Playground")
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        error = nil
        output = ""
        let config = GenerationConfig(
            maxTokens: Int(maxTokens),
            temperature: Float(temperature),
            stream: true
        )
        do {
            for try await delta in AIKit.stream(userPrompt, backend: backend, systemPrompt: systemPrompt, config: config) {
                output += delta
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
