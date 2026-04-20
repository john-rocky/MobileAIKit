# MobileAIKitDemo

Full iOS SwiftUI demo that exercises every major feature of MobileAIKit: chat, streaming, RAG, voice assistant, camera, OCR, web-search agent, benchmark, settings.

## Generate the Xcode project

```bash
brew install xcodegen
cd Samples/MobileAIKitDemo
xcodegen
open MobileAIKitDemo.xcodeproj
```

If you prefer not to install XcodeGen: create a new iOS App target in Xcode, drag the `Sources/` folder in, add the `MobileAIKit` package as a local package dependency (`Add Package... → Add Local...` pointing at `../..`), and link the products `AIKit`, `AIKitUI`, `AIKitLlamaCpp`, `AIKitSpeech`, `AIKitVision`, `AIKitIntegration`.

## What it does

On first launch the app downloads a small GGUF model (Qwen 2.5 0.5B, ~400 MB) via `ModelDownloader` with progress UI, then hands you a home screen with:

- Streaming chat
- Prompt playground
- Document Q&A (RAG pipeline with citations)
- Browse-and-ask (web search + page reader)
- Camera assistant
- OCR extractor
- Voice assistant (mic → LLM → voice)
- Web search agent (LLM with web_search and read_web_page tools)
- Benchmark and settings

## Swap the backend

Edit `App.swift` → `prepare()`. To use CoreML-LLM:

```swift
import AIKitCoreMLLLM
backend = CoreMLLLMBackend(model: .gemma4e2b)
```

To use Apple Foundation Models (iOS 26+):

```swift
import AIKitFoundationModels
backend = FoundationModelsBackend(instructions: "Be concise.")
```

To use MLX:

```swift
import AIKitMLX
backend = MLXBackend(modelId: "qwen-0.5b", hubRepoId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit")
```
