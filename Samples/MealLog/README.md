# MealLog — AI-powered meal journal with voice queries

Snap your plate, Gemma 4 identifies the dishes and estimates nutrition, everything is saved locally, and you can ask "how many calories yesterday?" by voice.

## Stack

- `CoreMLLLMBackend(model: .gemma4e2b)` — multimodal vision prompt
- `StructuredDecoder` + `JSONSchema` — typed `MealExtraction` with calories / macros / dietary flags
- `DatabaseMemoryStore` — SQLite-backed log, semantic search
- `SpeechToText.liveRecognition` — dictate your question
- `TextToSpeech.speakUtterance` — reads meal summary and answer aloud
- Daily totals computed in `MealStore.dailyTotals(on:)`

## Build

```bash
cd Samples/MealLog && xcodegen && open MealLog.xcodeproj
```

## Tabs

- **Today** — running total with macro breakdown, tap speaker for spoken daily summary.
- **Log** — PhotosPicker → "Log meal" triggers Gemma 4 which reads back the result.
- **Ask** — type or dictate "what did I eat yesterday?" — the answer is spoken as well as shown.
