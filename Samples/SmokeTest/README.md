# SmokeTest

Single-screen iOS app that runs every headline LocalAIKit public API against the bundled `CoreMLLLMBackend` in sequence and shows pass/fail per check. Use it as a post-merge dog-food step — open it on a real device, tap **Run all checks**, and verify everything the README advertises actually works end-to-end.

A second button, **Run Gemma 3 checks**, dog-foods the optional `FunctionGemmaBackend` + `EmbeddingGemmaEmbedder` paths (~720 MB cumulative first-run download from HuggingFace; cached thereafter under `Documents/LocalAIKit/models`).

## Checks covered

| Area | What it verifies |
|---|---|
| Backend metadata | `info.capabilities` contains everything we advertise (`.toolCalling`, `.vision`, `.streaming`, …) |
| `AIKit.chat` | Non-empty one-shot text generation |
| `AIKit.stream` | Token deltas actually arrive incrementally |
| `ChatSession` | Multi-turn history is preserved across sends |
| `AIKit.extract` | Schema-driven JSON extraction + repair pass |
| `AIKit.askWithTools` | Prompt-based tool calling: model emits `{"tool_calls":[…]}`, registry executes |
| `RAGPipeline` | Ingest → retrieve → answer w/ citations via `HashingEmbedder` |
| `DatabaseMemoryStore` | SQLite round-trip of embeddings + text |
| `AIKit.classify` | Zero-shot labelling via `extract` under the hood |
| `AIKit.analyzeImage` | Vision path through the VLM |
| `AIKit.ocr` | `AIKitVision` OCR on a rendered text bitmap |
| `TextAttachment` | `.text` attachment content reaches the model |
| `PDFAttachment` | `.pdf` is extracted (PDFKit) and inlined in the prompt |
| `FileAttachment` (text) | `.file` with a text MIME is read from disk and inlined |
| `BackendRouter` | Fallback from a failing backend to a healthy one |

### Opt-in Gemma 3 checks

| Area | What it verifies |
|---|---|
| `FunctionGemmaBackend` | Native function call (`<start_function_call>`…`<end_function_call>`) → `ToolRegistry` executes the tool |
| `EmbeddingGemmaEmbedder` | 768-d embedding with `.similarity` task prefix; similar sentences score higher cosine than unrelated ones |

What it does *not* cover (those need device-only permissions / hardware):

- Live mic (`SpeechToText.liveRecognition`)
- HealthKit writes (`HealthKitBridge.saveMeal`)
- Camera capture (`AICameraCaptureView`)

Those are covered by the dedicated samples (`VoiceInterpreter`, `MealLog`, `Moments`).

## Build and run

```bash
brew install xcodegen
cd Samples/SmokeTest
xcodegen
open SmokeTest.xcodeproj
```

Pick a real device (the model uses ANE via CoreML-LLM) and Run. First launch downloads Gemma 4 E2B (~1.5 GB); after that the checks run in a few seconds each.
