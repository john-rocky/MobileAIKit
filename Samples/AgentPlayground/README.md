# AgentPlayground

One-screen showcase of `AIAgentDefaultView` — a Gemma 4 agent wired up with **every built-in tool pack** plus four custom app tools. Tap a chip at the top and watch the model pick the right tool, ask for permission when needed, and speak the result.

## What's inside

```
Sources/
├── App.swift          # boots CoreMLLLMBackend(model: .gemma4e2b)
├── ContentView.swift  # NavigationStack + suggestion chips + AIAgentView
└── AppTools.swift     # add_todo / list_todos / complete_todo / roll_dice
```

## Tools registered at launch

| Source | Tools |
|---|---|
| `AgentTools.all` (host) | `take_photo`, `pick_photos`, `scan_document`, `scan_text`, `pick_location`, `pick_files`, `share`, `open_url` |
| `registerVisionTools` | `describe_image`, OCR |
| `registerSpeechTools` | `speak`, `transcribe` |
| `registerIntegrationTools` | calendar, contacts, HealthKit, MapKit, WeatherKit, location, web search + reader + HTTP, PDF, photos, motion, HomeKit, MusicKit, notifications, file I/O |
| `AppTools` | `add_todo`, `list_todos`, `complete_todo`, `roll_dice` |

## Run

```bash
brew install xcodegen
cd Samples/AgentPlayground
xcodegen && open AgentPlayground.xcodeproj
```

First launch downloads Gemma 4 E2B onto the device (~2 GB). Run on an iPhone with iOS 18+.

## Try these prompts

- "What's the weather like where I am?"
- "Add 'call the dentist tomorrow at 3pm' to my todos, then list them."
- "Find three coffee shops near me and share the top pick."
- "Take a photo and describe what you see."
- "Roll 4d20 and tell me the total."
- "Search the web for WWDC 2026 dates and add an event."

The agent mixes built-in tools (weather, maps, web, camera) and app tools (`add_todo`, `roll_dice`) in the same turn.

## Swapping the backend

`App.swift` boots `CoreMLLLMBackend(model: .gemma4e2b)`. Replace with any other `AIBackend`:

```swift
// Apple Foundation Models (iOS 26+)
import AIKitFoundationModels
let backend = FoundationModelsBackend(instructions: "Be concise.")

// llama.cpp GGUF
import AIKitLlamaCpp
let backend = LlamaCppBackend(modelPath: ggufURL, template: .auto(name: "gemma-4"))

// MLX on Apple Silicon
import AIKitMLX
let backend = MLXBackend(modelId: "mlx-gemma-4-e4b-it", hubRepoId: "mlx-community/gemma-4-e4b-it-4bit")
```
