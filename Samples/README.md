# LocalAIKit — Sample Apps

All samples are fully-runnable iOS SwiftUI apps that use `CoreMLLLMBackend(model: .gemma4e2b)` on-device. Every sample uses **on-device voice readback** (`TextToSpeech.speakUtterance`) so results are heard, not just seen.

Generate any one with:

```bash
brew install xcodegen
cd Samples/<Sample>
xcodegen && open <Sample>.xcodeproj
```

| Sample | One-liner | Core pieces exercised |
|---|---|---|
| [`AgentPlayground`](./AgentPlayground) | One-screen agent wired up with every built-in tool pack plus custom app tools — tap a chip and watch it call the right function | `AIAgentView`, `AgentKit.build`, host/integration/vision/speech tool packs, custom `TypedTool`s |
| [`MobileAIKitDemo`](./MobileAIKitDemo) | Swiss-army demo of every LocalAIKit feature | `AIChatView`, `AIDocumentQAView`, `AIVoiceAssistantView`, `AICameraAssistantView`, `AIBenchmarkView`, web-search agent |
| [`Moments`](./Moments) | Multimodal life journal: photo + voice → structured card stored in SQLite, searchable | `CoreMLLLMBackend`, `ImageAttachment`, `JSONSchema` + `StructuredDecoder`, `DatabaseMemoryStore`, `SpeechToText`, `TextToSpeech`, `LocationBridge` |
| [`VoiceInterpreter`](./VoiceInterpreter) | Two-way live interpreter — tap A or B, speak, hear the translation | `SpeechToText.liveRecognition`, `AIKit.translate`, `TextToSpeech.speakUtterance` (target locale) |
| [`MealLog`](./MealLog) | Snap meal → Gemma estimates nutrition; ask "how many calories yesterday?" by voice | `analyzeImage` via message attachment, `StructuredDecoder`, `DatabaseMemoryStore`, `SpeechToText`, `TextToSpeech` for totals + summaries |
| [`SceneReader`](./SceneReader) | Accessibility scene narrator: photo → OCR + VLM description, follow-up Q&A, all spoken aloud | `AIKit.ocr`, `AIKit.analyzeImage`, `TextToSpeech` (slower rate), `SpeechToText` for voice follow-ups |
| [`MeetingSummarizer`](./MeetingSummarizer) | Live meeting → structured minutes (decisions/actions/risks) with spoken readback per section | `SpeechToText.liveRecognition` (long-form), `AIKit.extract` with `MeetingExtraction` schema, `TextToSpeech` on every card |

## What to change

All samples default to `CoreMLLLMBackend(model: .gemma4e2b)`. To try a different model, swap for another `CoreMLLLMBackend.ModelInfo` — see `CoreMLLLMBackend.availableModels` for the built-in list.

All voice features use Apple's `SFSpeechRecognizer` / `AVSpeechSynthesizer` under the hood, so nothing leaves the device.
