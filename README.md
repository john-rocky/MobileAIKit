# MobileAIKit

Swift-first toolkit that lets you ship local, on-device AI apps on iOS, macOS, visionOS, tvOS, and watchOS in a few lines.

Pick any runtime — **CoreML-LLM, Apple Foundation Models, MLX, llama.cpp, generic CoreML** — behind one unified `AIBackend` protocol. Wire it into SwiftUI prefabs, structured output, tool calling, memory, RAG, web search, vision, and speech without leaving Swift.

## Install

Add the package in `Package.swift` or Xcode (File → Add Package Dependencies…):

```swift
.package(url: "https://github.com/john-rocky/MobileAIKit", branch: "main")
```

Choose the products you need:

| Product | What's inside |
|---|---|
| `AIKit` | Core protocols, chat, tools, memory, RAG, privacy, observability |
| `AIKitCoreMLLLM` | Wrapper over [john-rocky/coreml-llm](https://github.com/john-rocky/coreml-llm) |
| `AIKitFoundationModels` | Apple Foundation Models (iOS 26+) |
| `AIKitMLX` | mlx-swift LLM/VLM backend |
| `AIKitLlamaCpp` | llama.cpp GGUF backend |
| `AIKitCoreML` | Generic CoreML LLM + classifier backends |
| `AIKitVision` | OCR, image analysis, VisionKit DataScanner |
| `AIKitSpeech` | STT (SFSpeechRecognizer), TTS (AVSpeechSynthesizer) |
| `AIKitUI` | Chat, RAG, voice, camera, benchmark, memory inspector prefabs |
| `AIKitIntegration` | EventKit, Contacts, Photos, PDFKit, Maps, HealthKit, Motion, Web, Notifications |
| `AIKitAll` | Everything above |

## Quick start (1 line to chat)

```swift
let answer = try await AIKit.chat(
    "Explain Swift actors in one sentence.",
    backend: LlamaCppBackend(modelPath: modelURL)
)
```

## 3-line Chat UI

```swift
let backend = LlamaCppBackend(modelPath: modelURL)
let session = ChatSession(backend: backend, systemPrompt: "Be concise.")
AIChatView(session: session)
```

## 10-line RAG

```swift
let embedder = HashingEmbedder(dimension: 512)
let rag = RAGPipeline(embedder: embedder)
try await rag.ingest(text: notes, source: "notes.txt")
try await rag.ingest(text: pdfText, source: "report.pdf")

let backend = CoreMLLLMBackend(model: .gemma4e2b)
let answer = try await rag.ask("Summarise last quarter's results", backend: backend)
print(answer.answer)
print(answer.citations.map(\.source))
```

## Structured output (Codable)

```swift
struct Contact: Codable { let name: String; let email: String? }

let schema: JSONSchema = .object(
    properties: ["name": .string(), "email": .string(format: "email")],
    required: ["name"]
)
let contact: Contact = try await AIKit.extract(
    Contact.self, from: text, schema: schema, instruction: "Extract contact.", backend: backend
)
```

## Voice assistant (2 lines)

```swift
let assistant = try VoiceAssistant(backend: backend, locale: Locale(identifier: "ja-JP"))
AIVoiceAssistantView(assistant: assistant)
```

## Tool calling

```swift
let registry = ToolRegistry(cache: ToolResultCache(), retry: ToolRetry())
await registry.register(WebSearch.tool(provider: DuckDuckGoSearchProvider()))
await registry.register(EventKitBridge().createEventTool())

let answer = try await AIKit.askWithTools(
    "Search the web for WWDC keynote then add it to my calendar.",
    tools: registry,
    backend: backend
)
```

## Long-term memory on SQLite

```swift
let memory = try DatabaseMemoryStore(embedder: HashingEmbedder())
let session = ChatSession(backend: backend, memory: memory)
_ = try await session.send("Remember my birthday is May 14.")
```

## Pick a backend

```swift
// 1. Apple on-device model (iOS 26+)
let backend: any AIBackend = FoundationModelsBackend(instructions: "Be brief.")

// 2. CoreML-LLM (ANE-optimised, john-rocky/coreml-llm)
let backend = CoreMLLLMBackend(model: .gemma4e2b)

// 3. MLX (Apple Silicon)
let backend = MLXBackend(modelId: "qwen-0.5b", hubRepoId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit")

// 4. llama.cpp (GGUF)
let backend = LlamaCppBackend(modelPath: ggufURL)

// 5. Generic CoreML
let backend = CoreMLBackend(configuration: .init(modelURL: mlpackageURL, tokenizerRepoId: "Qwen/Qwen2.5-0.5B-Instruct"))
```

Or route between them with fallback:

```swift
let router = BackendRouter(backends: [
    FoundationModelsBackend(),
    CoreMLLLMBackend(model: .gemma4e2b),
    LlamaCppBackend(modelPath: ggufURL)
])
```

## Prefabs (SwiftUI)

| View | What it does |
|---|---|
| `AIChatView` | Full chat UI with streaming, attachments, tool calls |
| `AIPromptPlaygroundView` | Sliders for temperature/tokens/system |
| `AIDocumentQAView` | Chat against a RAG pipeline with citations |
| `AISearchView` | Hybrid vector+BM25 search over a `VectorIndex` |
| `AIVoiceAssistantView` | Mic → STT → LLM → TTS loop |
| `AICameraAssistantView` | Snap photo → describe with vision backend |
| `AIOCRExtractionView` | Add images → recognise text |
| `AIFormFillView` | Paste source text → auto-fill form fields |
| `AIStructuredResultView` | Render `Codable` output inline |
| `AIModelDownloadView` | Resumable downloader with progress |
| `AIApprovalSheet` | Approval UI for side-effect tools |
| `AIToolExecutionLogView` | Tool call audit log |
| `AIMemoryInspectorView` | Browse + forget memories |
| `AIBenchmarkView` | Run prompts, measure tok/s, TTFT |
| `AIDebugPanelView` | Telemetry timeline |
| `AISettingsView` | Quality profile, thermal policy, disk usage |
| `AIPrefabGallery` | Index into all of the above |

## iOS integration highlights

- **Vision**: OCR (`AIKit.ocr`), image analysis, VisionKit live DataScanner
- **Speech**: `AIKit.transcribe(audio:)`, `AIKit.speak(text:)`, live mic
- **Web**: DuckDuckGo, Brave, Bing search; web page reader; `AIKit.browseAndAsk`
- **PDF**: `AIKit.readPDF`, `AIKit.askPDF`
- **EventKit, Contacts, Photos, HealthKit, CoreMotion, CoreLocation, MapKit, StoreKit, CoreHaptics**: all wrapped as typed tools
- **AppIntents & Shortcuts**: `AIKitChatIntent` for Siri
- **Widgets, Live Activities, Background Tasks, UserNotifications, Handoff, URL schemes, Share Extension**: helper bridges

## Privacy & safety

```swift
await PrivacyGuard.shared.setPolicy(.strictLocal)
let telemetry = Telemetry(localOnly: true, privacyRedactor: Redaction.redactor())
let safety = SafetyPolicy(promptInjectionDetector: SafetyPolicy.defaultInjectionDetector)
```

Encrypted export via Keychain-backed AES-GCM:

```swift
try EncryptedStorage.writeEncrypted(data, to: url, keyTag: "memory")
```

## Performance

```swift
await ResourceGovernor.shared.setPreferredProfile(.balanced)
await ResourceGovernor.shared.setThermalDegradation(true)

let recorder = BenchmarkRecorder()
_ = try await recorder.run(name: "llama-3.2-1b", backend: backend, prompts: prompts)
```

## License

MIT. See `LICENSE`.
