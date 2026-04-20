# Memory

Give your assistant persistent memory.

## Ephemeral (in-memory)

```swift
let memory = InMemoryStore(embedder: HashingEmbedder())
let session = ChatSession(backend: backend, memory: memory)
```

## JSON-file persistent

```swift
let memory = try PersistentMemoryStore(embedder: HashingEmbedder())
```

## SQLite long-term (recommended)

```swift
let memory = try DatabaseMemoryStore(embedder: HashingEmbedder())
```

Stores records in WAL-mode SQLite with an FTS5 full-text index. Embeddings live in a BLOB column; search mixes cosine similarity, keyword match, recency, and importance.

## Kinds

`MemoryKind.shortTerm`, `.longTerm`, `.summary`, `.entity`, `.pinned`, `.semantic`, `.episodic`, `.user`, `.workflow`.

## Explicit store/retrieve

```swift
try await memory.store(MemoryRecord(kind: .longTerm, text: "Birthday: May 14", importance: 0.9))
let hits = try await memory.retrieve(query: "birthday", limit: 3)
```

## Compaction & summarisation

```swift
let memory = try DatabaseMemoryStore(
    embedder: embedder,
    maxShortTerm: 500,
    summarizer: { records in
        try await AIKit.summarize(records.map(\.text).joined(separator: "\n"), backend: backend)
    }
)
try await memory.compact(namespace: "default")
```

## Inspector UI

```swift
AIMemoryInspectorView(memory: memory)
```

## Export / import / encrypted backup

```swift
let data = try await memory.exportAll()
try EncryptedStorage.writeEncrypted(data, to: url, keyTag: "memory")
```
