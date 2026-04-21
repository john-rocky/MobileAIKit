# RAG

Retrieval-augmented generation with citations in a few lines.

## Build

```swift
let embedder = HashingEmbedder(dimension: 512)
let rag = RAGPipeline(embedder: embedder)
try await rag.ingest(text: notesText, source: "notes.txt")
try await rag.ingest(text: pdfText, source: "spec.pdf")
```

## Ask with citations

```swift
let result = try await rag.ask("What's the SLA?", backend: backend)
print(result.answer)
for citation in result.citations {
    print("- \(citation.source): \(citation.text)")
}
```

## Stream

```swift
for try await delta in rag.askStream("Summarise Q4 results", backend: backend) {
    print(delta, terminator: "")
}
```

## Hierarchical chunking and reranking

```swift
let chunker = HierarchicalChunker()
let pipeline = RAGPipeline(
    embedder: embedder,
    chunker: Chunker(maxCharacters: 800, overlap: 100),
    reranker: Rerankers.mmr(lambda: 0.7)
)
```

## Bring your own source trust

```swift
let pipeline = RAGPipeline(
    embedder: embedder,
    sourceTrustScore: { source in source.contains("official") ? 1.2 : 1.0 }
)
```

## PDF one-liner

```swift
let answer = try await AIKit.askPDF("When does SLA reset?", pdfURL: url, backend: backend)
```

## UI

```swift
AIDocumentQAView(backend: backend, pipeline: rag)
```
