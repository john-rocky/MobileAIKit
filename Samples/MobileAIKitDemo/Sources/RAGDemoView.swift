import SwiftUI
import AIKit
import AIKitUI

struct RAGDemoView: View {
    let backend: any AIBackend

    @State private var pipeline: RAGPipeline?
    @State private var isReady = false
    @State private var noteText: String = """
    MobileAIKit is a Swift toolkit that wraps CoreML-LLM, MLX, llama.cpp and
    Apple Foundation Models behind a single AIBackend protocol.

    It provides long-term memory, RAG, tools, and SwiftUI prefabs so that
    developers can build on-device AI apps in a few lines of Swift.
    """

    var body: some View {
        VStack {
            if let pipeline, isReady {
                AIDocumentQAView(backend: backend, pipeline: pipeline)
            } else {
                VStack(spacing: 12) {
                    Text("Paste your source text").font(.headline)
                    TextEditor(text: $noteText).frame(minHeight: 200).border(.secondary.opacity(0.3))
                    Button("Index and open Q&A") { Task { await index() } }
                        .buttonStyle(.borderedProminent)
                }.padding()
            }
        }
        .navigationTitle("Document Q&A")
    }

    private func index() async {
        let embedder = HashingEmbedder(dimension: 384)
        let pipeline = RAGPipeline(embedder: embedder)
        try? await pipeline.ingest(text: noteText, source: "demo-notes")
        self.pipeline = pipeline
        self.isReady = true
    }
}
