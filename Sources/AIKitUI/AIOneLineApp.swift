import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIChatApp: View {
    public let backend: any AIBackend
    public let systemPrompt: String?
    @State private var session: ChatSession?

    public init(backend: any AIBackend, systemPrompt: String? = nil) {
        self.backend = backend
        self.systemPrompt = systemPrompt
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let session {
                    AIChatView(session: session)
                        .navigationTitle("AI Chat")
                } else {
                    ProgressView("Preparing…")
                        .task {
                            session = ChatSession(backend: backend, systemPrompt: systemPrompt)
                        }
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIRAGApp: View {
    public let backend: any AIBackend
    public let documents: [Document]

    @State private var pipeline: RAGPipeline?
    @State private var ready = false

    public init(backend: any AIBackend, documents: [Document]) {
        self.backend = backend
        self.documents = documents
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let pipeline, ready {
                    AIDocumentQAView(backend: backend, pipeline: pipeline)
                        .navigationTitle("Document Q&A")
                } else {
                    ProgressView("Indexing documents…")
                        .task { await prepare() }
                }
            }
        }
    }

    private func prepare() async {
        let embedder = HashingEmbedder(dimension: 512)
        let pipeline = RAGPipeline(embedder: embedder)
        for doc in documents { try? await pipeline.ingest(doc) }
        self.pipeline = pipeline
        self.ready = true
    }
}
