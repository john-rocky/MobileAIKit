# Vision

OCR and image analysis via Vision framework, plus LLM vision through VLM backends.

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
let answer = try await AIKit.analyzeImage(attachment, backend: MLXVLMBackend(
    modelId: "qwen-vl",
    hubRepoId: "mlx-community/Qwen2-VL-2B-Instruct-4bit"
))
```

## Live data scanner (iOS)

```swift
AIDataScannerView(recognizedDataTypes: [.text(), .barcode()]) { value in
    print(value)
}
```

## CoreML classifier as tool

```swift
let classifier = try CoreMLClassifierTool.load(name: "FoodClassifier", at: mlmodelURL)
await registry.register(classifier.asTool())
```
