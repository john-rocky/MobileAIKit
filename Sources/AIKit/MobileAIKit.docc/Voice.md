# Voice

STT + LLM + TTS in two lines.

## Quick transcribe

```swift
let text = try await AIKit.transcribe(audio: audio)
```

## Speak

```swift
await AIKit.speak("Hello there.")
```

## Full voice assistant (mic → LLM → voice)

```swift
let assistant = try VoiceAssistant(backend: backend, locale: .init(identifier: "ja-JP"))
for try await event in assistant.run() {
    switch event {
    case .partialTranscript(let t): print("You:", t)
    case .finalAnswer(let answer): print("AI:", answer)
    default: break
    }
}
```

## SwiftUI UI

```swift
AIVoiceAssistantView(assistant: assistant)
```
