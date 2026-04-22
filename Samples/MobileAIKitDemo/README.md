# MobileAIKitDemo

Full iOS SwiftUI demo that exercises every major feature of LocalAIKit: chat, streaming, RAG, voice assistant, camera, OCR, web-search agent, benchmark, settings.

## Generate the Xcode project

```bash
brew install xcodegen
cd Samples/MobileAIKitDemo
xcodegen
open MobileAIKitDemo.xcodeproj
```

If you prefer not to install XcodeGen: create a new iOS App target in Xcode, drag the `Sources/` folder in, add the `LocalAIKit` package as a local package dependency (`Add Package... → Add Local...` pointing at `../..`), and link the products `AIKit`, `AIKitUI`, `AIKitCoreMLLLM`, `AIKitSpeech`, `AIKitVision`, `AIKitIntegration`.

## What it does

On first launch the app downloads Gemma 4 E2B (multimodal, CoreML-LLM) via the backend's own downloader with status UI, then hands you a home screen with:

- Streaming chat
- Prompt playground
- Document Q&A (RAG pipeline with citations)
- Browse-and-ask (web search + page reader)
- Camera assistant
- OCR extractor
- Voice assistant (mic → LLM → voice)
- Web search agent (LLM with web_search and read_web_page tools)
- Benchmark and settings

## Try a different model

Edit `App.swift` → `prepare()` and pass a different `CoreMLLLMBackend.ModelInfo` (see `CoreMLLLMBackend.availableModels`).
