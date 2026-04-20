# ``AIKit``

Swift-first toolkit for shipping local, on-device AI apps.

## Overview

`AIKit` lets you pick any runtime (CoreML-LLM, Apple Foundation Models, MLX, llama.cpp, CoreML) behind one `AIBackend` protocol, and compose chat, tools, memory, RAG, web search, vision, and speech with minimal Swift code.

```swift
let session = ChatSession(backend: LlamaCppBackend(modelPath: url))
let answer = try await session.send("Explain actors.")
```

## Topics

### Getting started
- <doc:GettingStarted>
- <doc:PickABackend>
- <doc:ChatIn3Lines>

### Structured output and tools
- <doc:StructuredOutput>
- <doc:ToolCalling>

### Memory and retrieval
- <doc:Memory>
- <doc:RAG>
- <doc:WebSearch>

### Multimodal
- <doc:Vision>
- <doc:Voice>
- <doc:Camera>

### iOS integration
- <doc:iOSFrameworks>
- <doc:AppIntents>

### Performance and privacy
- <doc:Performance>
- <doc:Privacy>

### Reference
- ``AIKit``
- ``AIBackend``
- ``ChatSession``
- ``BackendRouter``
- ``RAGPipeline``
- ``ToolRegistry``
- ``Skills``
- ``MemoryStoreProtocol``
- ``InMemoryStore``
- ``DatabaseMemoryStore``
- ``Telemetry``
- ``BenchmarkRecorder``
- ``PrivacyPolicy``
