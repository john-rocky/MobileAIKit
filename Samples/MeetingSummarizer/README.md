# MeetingSummarizer — live meetings → structured minutes

Record a meeting on-device, Gemma 4 turns the raw transcript into structured minutes (decisions, action items with owners and due dates, risks, open questions). The summary is read aloud, per-section.

## Stack

- `CoreMLLLMBackend(model: .gemma4e2b)`
- `SpeechToText.liveRecognition` — continuous streaming transcript
- `AIKit.extract(MeetingExtraction.self, …)` + `MeetingExtraction.schema`
- `TextToSpeech.speakUtterance` — toolbar button reads summary; per-section buttons read decisions, actions, risks, open questions
- JSON-file backed `MeetingStore` for history

## Build

```bash
cd Samples/MeetingSummarizer && xcodegen && open MeetingSummarizer.xcodeproj
```

## Flow

1. **Start a new meeting** — big red record button, live running clock.
2. **Speak** — partial transcript streams into the middle panel.
3. **Finish & summarise** — Gemma 4 extracts structured minutes in a few seconds.
4. **Summary view** — per-section cards with a speaker icon each, toolbar "Read summary" button plays the whole thing.
5. **History** — past meetings, tap to re-open the summary.
