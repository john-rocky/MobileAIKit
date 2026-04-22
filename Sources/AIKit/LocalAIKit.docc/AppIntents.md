# App Intents & Siri

Expose your AI features to Shortcuts and Siri.

```swift
import AIKitIntegration

AIKitChatIntent.backendProvider = { CoreMLLLMBackend(model: .gemma4e2b) }
// Siri: "Ask MyApp ..."
```

## Register more intents

Define your own `AppIntent` and call `AIKit.chat` or `AIKit.extract` inside `perform()`.
