# Camera

## Describe a photo with VLM

```swift
let backend = CoreMLLLMBackend(model: .gemma4e2b)
let caption = try await AIKit.analyzeImage(
    ImageAttachment(source: .fileURL(url)),
    prompt: "Describe what's happening and what's notable.",
    backend: backend
)
```

## Sample video frames + ask

```swift
let frames = try await FrameSampler(maxFrames: 12).sample(videoURL: videoURL)
let caption = try await AIKit.analyzeImages(frames, prompt: "Summarise the video.", backend: backend)
```

## Live data scanner UI

```swift
AIDataScannerView { scanned in
    print(scanned)
}
```

## Prefab

```swift
AICameraAssistantView(backend: backend)
```
