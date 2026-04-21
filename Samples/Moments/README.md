# Moments — on-device AI journal with Gemma 4

**Moments** is a tiny life-journaling app that runs entirely on your device. Snap a photo, say a short voice note, and let **Gemma 4 E2B** (via CoreML-LLM + ANE) weave them into a structured memory card. Everything is saved to a local SQLite store so you can semantically search your own life later without any data leaving the phone.

It exercises LocalAIKit end to end:

| Feature | LocalAIKit piece used |
|---|---|
| Multimodal (image + voice prompt) | `CoreMLLLMBackend(model: .gemma4e2b)` with `Attachment.image` |
| Structured output | `MomentExtraction` + `StructuredDecoder` over a `JSONSchema` |
| Speech-to-text | `SpeechToText.liveRecognition()` on-device |
| Text-to-speech readback | `TextToSpeech.speakUtterance(...)` |
| Long-term memory | `DatabaseMemoryStore` (WAL-mode SQLite + FTS5 + embeddings) |
| Semantic search | `memory.retrieve(query:)` with `HashingEmbedder` |
| RAG over memories | Manual top-k context + `AIKit.chat` |
| Location | `LocationBridge.currentLocation()` + CLGeocoder |
| Prefabs | Hand-rolled UI here; see `MobileAIKitDemo` for `AIChatView`, `AIVoiceAssistantView`, etc. |

## Build

```bash
brew install xcodegen
cd Samples/Moments
xcodegen
open Moments.xcodeproj
```

Select a device (real device recommended — Gemma 4 uses the Neural Engine through CoreML-LLM).

## How it works

1. **Bootstrap** (`App.swift`): creates `MomentStore`, loads Gemma 4 E2B via `CoreMLLLMBackend`.
2. **Capture** (`CaptureView`):
   - PhotosPicker → `Data` → `ImageAttachment`
   - Tap and speak → `SpeechToText.liveRecognition()` streams partial transcripts
   - Tap *Save* → Gemma 4 receives `Message.user(prompt, attachments: [.image(…)])`
   - A `JSONSchema` (title / narrative / tags / rows / mood) is embedded in the system prompt
   - `StructuredDecoder` turns the model's JSON into a `MomentExtraction`
   - The resulting `Moment` (plus image) is persisted and its `embedText` is indexed in SQLite memory
3. **Timeline** (`TimelineView`): browse and `.searchable` runs `store.search(query)` which hits the vector+keyword memory.
4. **Ask** (`AskMemoriesView`): retrieves top-k memories, formats them as context, and calls `AIKit.chat` for a warm summary.
5. **Detail** (`DetailView`): tap the speaker icon to have Gemma's narrative read aloud via `TextToSpeech`.

## Try these prompts

In the **Ask** tab, once you have a few moments:

- "Show me calm moments from this week"
- "Any moments involving coffee?"
- "Where was I on Saturday afternoon?"
- "What's a recurring theme in my life lately?"

## Privacy

Zero network. The model runs through Apple's Neural Engine via CoreML-LLM. Photos, audio, transcripts, and the SQLite memory file all live under `Application Support/Moments/`. Delete the app → data is gone.

## Variations to try

- Swap `CoreMLLLMBackend(model: .gemma4e2b)` for `LlamaCppBackend(modelPath: …)` with `ModelCatalog.gemma4_e2b_Q4` to run the GGUF path.
- Replace `HashingEmbedder` with `NLEmbedder(language: .english)` for better semantic search.
- Add an `AIBenchmarkView` tab to compare E2B vs E4B on your device.
- Wrap `MomentStore.add(_:)` with `GenerationActivityController` to show a Live Activity while Gemma is writing.
