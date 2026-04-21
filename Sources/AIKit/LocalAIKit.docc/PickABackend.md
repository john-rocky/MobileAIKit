# Pick a Backend

AIKit ships five backends. Pick the one that matches your device / model file.

## Apple Foundation Models (iOS 26+)

Runs Apple's built-in on-device model. No download, no model file.

```swift
import AIKitFoundationModels
let backend = FoundationModelsBackend(instructions: "Be concise.")
```

## CoreML-LLM (ANE-optimised)

[john-rocky/coreml-llm](https://github.com/john-rocky/coreml-llm) — best Neural Engine throughput for supported models, multimodal.

```swift
import AIKitCoreMLLLM
let backend = CoreMLLLMBackend(model: .gemma4e2b)
```

## MLX (Apple Silicon)

Uses `mlx-swift-examples`. Great on macOS/iPadOS, supports LLM and VLM.

```swift
import AIKitMLX
let backend = MLXBackend(modelId: "qwen-0.5b", hubRepoId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit")
```

## llama.cpp (GGUF)

Widest model catalogue. Metal-accelerated.

```swift
import AIKitLlamaCpp
let backend = LlamaCppBackend(modelPath: ggufURL, template: .chatML)
```

## Generic CoreML

Bring your own `.mlpackage`/`.mlmodelc` with a Hugging Face tokenizer.

```swift
import AIKitCoreML
let backend = CoreMLBackend(configuration: .init(
    modelURL: modelURL,
    tokenizerRepoId: "Qwen/Qwen2.5-0.5B-Instruct"
))
```

## Router with fallback

```swift
let router = BackendRouter(backends: [
    FoundationModelsBackend(),
    CoreMLLLMBackend(model: .gemma4e2b),
    LlamaCppBackend(modelPath: ggufURL)
])
```

## Capability discovery

```swift
if backend.info.capabilities.contains(.vision) {
    // attach images
}
```
