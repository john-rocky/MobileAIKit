# SmokeTest

Single-screen iOS app that runs every headline LocalAIKit public API against the bundled `CoreMLLLMBackend` in sequence and shows pass/fail per check. Use it as a post-merge dog-food step — open it on a real device, tap **Run all checks**, and verify everything the README advertises actually works end-to-end.

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
| `BackendRouter` | Fallback from a failing backend to a healthy one |

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
