import SwiftUI
import AIKit
import AIKitIntegration

struct WebSearchAgentView: View {
    let backend: any AIBackend

    @State private var request: String = "What's new in Swift 6.1?"
    @State private var answer: String = ""
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 12) {
            TextField("Ask anything", text: $request)
                .textFieldStyle(.roundedBorder).onSubmit(run).padding(.horizontal)
            Button(isRunning ? "Thinking…" : "Run") { run() }
                .disabled(isRunning || request.isEmpty)
                .buttonStyle(.borderedProminent)
            ScrollView { Text(answer).padding() }
        }
        .navigationTitle("Web Search Agent")
    }

    private func run() {
        Task {
            isRunning = true
            defer { isRunning = false }
            do {
                let registry = ToolRegistry(cache: ToolResultCache(), retry: ToolRetry())
                await registry.register(WebSearch.tool(provider: DuckDuckGoSearchProvider()))
                await registry.register(WebPageReader.readerTool())
                answer = try await AIKit.askWithTools(
                    request,
                    tools: registry,
                    backend: backend,
                    systemPrompt: "Use web_search and read_web_page when needed. Cite URLs."
                )
            } catch {
                answer = "Error: \(error.localizedDescription)"
            }
        }
    }
}
