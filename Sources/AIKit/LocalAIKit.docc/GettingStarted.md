# Getting Started

Go from zero to a chat UI in three lines.

## Add the package

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/john-rocky/LocalAIKit", branch: "main")
]
```

Link the targets you need. For the simplest chat flow: `AIKit`, one backend, and `AIKitUI`.

## Run your first prompt

```swift
import AIKit
import AIKitLlamaCpp

let backend = LlamaCppBackend(modelPath: modelURL)
let answer = try await AIKit.chat("Say hi in Japanese.", backend: backend)
print(answer)
```

## Stream the response

```swift
for try await delta in AIKit.stream("Tell me a haiku.", backend: backend) {
    print(delta, terminator: "")
}
```

## Show chat UI

```swift
import AIKitUI

struct ContentView: View {
    var body: some View {
        let backend = LlamaCppBackend(modelPath: modelURL)
        let session = ChatSession(backend: backend, systemPrompt: "Be concise.")
        AIChatView(session: session)
    }
}
```
