import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIBenchmarkView: View {
    public let backend: any AIBackend
    public var recorder: BenchmarkRecorder

    @State private var prompts: String = "Write a haiku about sunrise.\nExplain vectors in one sentence."
    @State private var isRunning: Bool = false
    @State private var runs: [BenchmarkRun] = []
    @State private var error: String?

    public init(backend: any AIBackend, recorder: BenchmarkRecorder = .init()) {
        self.backend = backend
        self.recorder = recorder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompts (one per line)").font(.headline)
            TextEditor(text: $prompts).frame(minHeight: 120).border(.secondary.opacity(0.2))
            Button(isRunning ? "Running…" : "Run benchmark") { Task { await run() } }
                .disabled(isRunning)
                .buttonStyle(.borderedProminent)
            if let error { Text(error).foregroundStyle(.red) }
            List(runs, id: \.runAt) { run in
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.prompt).font(.caption).lineLimit(1)
                    HStack {
                        Label(String(format: "%.1f tok/s", run.tokensPerSecond), systemImage: "speedometer")
                        Label(String(format: "TTFT %.2fs", run.firstTokenSeconds), systemImage: "timer")
                        Label("\(run.completionTokens) tokens", systemImage: "text.alignleft")
                    }.font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("Benchmark")
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        error = nil
        do {
            let list = prompts.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            runs = try await recorder.run(name: backend.info.name, backend: backend, prompts: list)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
