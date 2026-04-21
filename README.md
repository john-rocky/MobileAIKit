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
| `AIKitSpeech` | STT (SFSpeechRecognizer), TTS (AVSpeechSynthesizer, Premium/Personal voices) |
| `AIKitWhisperKit` | High-accuracy STT via [WhisperKit](https://github.com/argmaxinc/WhisperKit) (on-device Whisper) |
| `AIKitUI` | Chat, RAG, voice, camera, benchmark, memory inspector prefabs |
| `AIKitIntegration` | EventKit, Contacts, Photos, PDFKit, Maps, HealthKit, Motion, Web, Notifications |
| `AIKitAgent` | Drop-in AI Agent that can drive the whole app — camera, pickers, every integration, your own tools |
| `AIKitAll` | Everything above |

## Drop-in AI Agent (zero config)

Add one view. The user types a prompt; the model picks from every tool this platform exposes — camera, photo library, calendar, contacts, maps, weather, HealthKit, web, vision, speech — plus any custom tools you register.

```swift
import SwiftUI
import AIKit
import AIKitAgent

struct ContentView: View {
    let backend: any AIBackend
    var body: some View {
        AIAgentDefaultView(backend: backend)   // entire assistant in 1 line
    }
}
```

Add your own app-specific action:

```swift
AIAgentDefaultView(
    backend: backend,
    extraTools: [AppTools.addToCartTool(cart: cart)]
)
```

Headless (Siri shortcut / background task):

```swift
let agent = await AgentKit.build(backend: backend)  // no UI host attached
let reply = try await agent.send("Summarize my meetings today.").content
```

How it works: `AIAgent` owns a `ChatSession` and a `ToolRegistry`. UI-presenting tools (camera, scanner, location picker, share sheet) route through an `AgentHost` protocol — `AIAgentView` installs itself as the host automatically; headless agents get `NullAgentHost`, so UI tools fail with a clear error the model can handle. Tools marked `requiresApproval` always prompt the user via `AgentHost.confirm` before running.

## Quick start (1 line to chat)

```swift
let answer = try await AIKit.chat(
    "Explain Swift actors in one sentence.",
    backend: LlamaCppBackend(modelPath: modelURL)
)
```

## One-liner recipes

```swift
let backend = CoreMLLLMBackend(model: .gemma4e2b)

// Multimodal: UIImage + question in 1 line
let caption = try await AIKit.chat("What is happening here?", image: uiImage, backend: backend)

// Multiple images
let summary = try await AIKit.analyzeImages([image1, image2, image3], prompt: "Compare.", backend: backend)

// OCR from a UIImage
let text = try await AIKit.ocr(uiImage)

// Web search → LLM answer with citations (1 line)
let news = try await AIKit.askWeb("What did Apple announce this week?", backend: backend)

// Or let the LLM decide when to search (tool-calling agent)
let research = try await AIKit.askWithWebTools("Compare Qwen 3 vs Gemma 4 on math benchmarks.", backend: backend)

// Raw search results (no LLM)
let results: [WebSearchResult] = try await AIKit.searchWeb("latest SwiftUI news")

// PDF Q&A
let answer = try await AIKit.askPDF("When does SLA reset?", pdfURL: url, backend: backend)

// Voice
let transcript = try await AIKit.transcribe(audio: audio)
await AIKit.speak("こんにちは", locale: Locale(identifier: "ja"))

// High-accuracy Whisper (on-device, via WhisperKit)
let text = try await AIKit.transcribeWithWhisper(audio: audio, language: "ja")

// High-quality read-aloud (picks Premium/Enhanced voice when installed)
await AIKit.speakHQ("こんにちは、今日はいい天気ですね。", locale: Locale(identifier: "ja-JP"))
```

## Holding a model instance (important)

Every backend is a reference type. Create **one** and reuse it — don't instantiate inside hot paths:

```swift
// ❌ Creates + loads the model on every call (slow)
try await AIKit.chat("hi", backend: CoreMLLLMBackend(model: .gemma4e2b))

// ✅ Own it once
let backend = CoreMLLLMBackend(model: .gemma4e2b)
try await backend.load()           // optional: eager warm-up
try await AIKit.chat("hi", backend: backend)
try await AIKit.chat("again", backend: backend)
```

For SwiftUI, use the `AIBackendHost` wrapper — one instance for the whole app, injected through the environment:

```swift
@main struct MyApp: App {
    @State private var host = AIBackendHost { CoreMLLLMBackend(model: .gemma4e2b) }
    var body: some Scene {
        WindowGroup {
            RootView().aiBackendHost(host)     // loads once, keeps it alive
        }
    }
}

struct RootView: View {
    @Environment(AIBackendHost.self) private var host
    var body: some View {
        if let backend = host.backend {
            AIChatView(session: ChatSession(backend: backend))
        } else if host.isLoading {
            ProgressView()
        }
    }
}
```

Call `host.unload()` on memory warnings, `host.reload()` to swap models.

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

Vision-based extraction (food photo → nutrition, receipt → line items):

```swift
import AIKitIntegration   // for NutritionEntry.jsonSchema

let nutrition: NutritionEntry = try await AIKit.extract(
    NutritionEntry.self,
    from: uiImage,                        // UIImage / NSImage / ImageAttachment / Data
    schema: NutritionEntry.jsonSchema,
    instruction: NutritionEntry.defaultInstruction,
    backend: backend
)

// Sync to Apple Health in one call
let hk = HealthKitBridge()
try await hk.requestNutritionAuthorization()
try await hk.saveMeal(nutrition)
```

Stream tokens live during a slow VLM extract (keeps users looking at real output instead of a spinner):

```swift
for try await event in AIKit.streamingExtract(
    NutritionEntry.self,
    from: ImageAttachment(jpeg: data),
    schema: NutritionEntry.jsonSchema,
    backend: backend
) {
    switch event {
    case .delta(let s): liveText += s
    case .value(let n): nutrition = n
    }
}
```

When decoding fails, ``StructuredExtractionError`` preserves the raw model output so you can surface it or log it:

```swift
} catch let e as StructuredExtractionError {
    print(e.rawText)       // exactly what the model said
    print(e.underlying)    // the JSON / schema error
}
```

## Voice assistant (2 lines)

```swift
let assistant = try VoiceAssistant(backend: backend, locale: Locale(identifier: "ja-JP"))
AIVoiceAssistantView(assistant: assistant)
```

### High-accuracy voice stack (Whisper + Premium TTS)

```swift
import AIKitSpeech
import AIKitWhisperKit

// On-device Whisper (CoreML) — much higher accuracy than SFSpeechRecognizer,
// especially for noisy audio or non-English speech.
let whisper = WhisperSpeechToText(config: .init(
    model: "large-v3-v20240930_626MB",   // or nil to auto-pick
    language: "ja"                        // nil to auto-detect
))
try await whisper.preload()

// Premium read-aloud — picks the best installed voice for the locale.
// Ask users to install Enhanced/Premium voices under
// Settings → Accessibility → Spoken Content → Voices.
let tts = TextToSpeech(
    locale: Locale(identifier: "ja-JP"),
    quality: .best            // or .premium / .enhanced / .personal
)

let assistant = VoiceAssistant(
    backend: backend,
    whisper: .init(language: "ja"),
    speaker: tts,
    systemPrompt: "You are a concise spoken assistant."
)
```

One-liner file transcription with Whisper:

```swift
let text = try await AIKit.transcribeWithWhisper(audio: audio, language: "ja")

// Or with segment timestamps:
let detailed = try await AIKit.transcribeWithWhisperDetailed(audio: audio, wordTimestamps: true)
for seg in detailed.segments { print(seg.start, seg.end, seg.text) }
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
let backend = MLXBackend(modelId: "qwen3-1.7b", hubRepoId: "mlx-community/Qwen3-1.7B-4bit")

// 4. llama.cpp (GGUF)
let backend = LlamaCppBackend(modelPath: ggufURL)

// 5. Generic CoreML
let backend = CoreMLBackend(configuration: .init(modelURL: mlpackageURL, tokenizerRepoId: "Qwen/Qwen3-1.7B-Instruct"))
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
| `AICameraAssistantView` | PhotosPicker → describe with vision backend |
| `AICameraCaptureView` | Live `AVCaptureSession` with shutter — 1-tap meal / scan capture |
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
