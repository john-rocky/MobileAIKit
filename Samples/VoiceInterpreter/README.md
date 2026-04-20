# VoiceInterpreter

Two-way on-device interpreter powered by **Gemma 4 E2B**. Pick two languages, tap a speaker's mic, talk naturally — the app transcribes, translates, reads aloud in the listener's language, and remembers the whole conversation.

## Flow

1. `CoreMLLLMBackend(model: .gemma4e2b)` boots on launch (ANE).
2. Tap the **A** mic → `SpeechToText` listens in side A's locale and streams partial text live.
3. Final transcript → `AIKit.translate(text, to: side B language, backend:)` (Skills-backed).
4. Translation is printed into a chat bubble and optionally spoken with `TextToSpeech` in side B's locale.
5. Tap the **B** mic to answer — the reverse direction happens automatically.

Toggle the speaker icon in the top-right to disable auto-readback.

## Build

```bash
brew install xcodegen
cd Samples/VoiceInterpreter
xcodegen
open VoiceInterpreter.xcodeproj
```

11 language presets ship in `Utterance.swift`; add more by extending `LanguagePair.presets`. Everything stays on-device — no network required once the model is loaded.
