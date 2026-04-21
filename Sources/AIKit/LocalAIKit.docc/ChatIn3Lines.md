# Chat UI in 3 Lines

End-to-end SwiftUI chat app, including streaming, attachments, and tool calls.

```swift
let backend = LlamaCppBackend(modelPath: modelURL)
let session = ChatSession(backend: backend, systemPrompt: "Be concise.")
AIChatView(session: session)
```

## Customise

```swift
session.config = GenerationConfig(maxTokens: 512, temperature: 0.4)
session.systemPrompt = "Respond in bullet points."
```

## Attach an image

```swift
let attachment = ImageAttachment(source: .fileURL(url))
_ = try await session.send("What's in this picture?", attachments: [.image(attachment)])
```

## Restore and save

```swift
let snapshot = session.snapshot()
// later
session.restore(snapshot)
```
