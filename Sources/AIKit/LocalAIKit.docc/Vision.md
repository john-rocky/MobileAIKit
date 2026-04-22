# Vision

OCR and image analysis via the Vision framework, plus LLM vision through
``CoreMLLLMBackend`` (multimodal via Neural Engine).

## OCR

```swift
let text = try await AIKit.ocr(fileURL: imageURL).text
```

## Image analysis (faces, barcodes, rectangles)

```swift
let result = try await AIKit.imageAnalysis(attachment)
```

## VLM (vision-language)

```swift
let backend = CoreMLLLMBackend(model: .gemma4e2b)
let answer = try await AIKit.analyzeImage(attachment, backend: backend)
```

## Live data scanner (iOS)

```swift
AIDataScannerView(recognizedDataTypes: [.text(), .barcode()]) { value in
    print(value)
}
```
