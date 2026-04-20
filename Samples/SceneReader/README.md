# SceneReader — accessibility-focused scene narrator

Point the camera at the world. Gemma 4 describes what it sees, Vision OCR reads any printed text, and the phone speaks both aloud. Follow-up questions can be typed or dictated.

## Stack

- `CoreMLLLMBackend(model: .gemma4e2b)` multimodal vision prompting
- `AIKit.ocr(image:)` → `VNRecognizeText` for signs and menus
- `AIKit.analyzeImage(_:prompt:backend:)` → on-device narration
- `TextToSpeech.speakUtterance` with a slightly slower rate for clarity
- `SpeechToText.liveRecognition` for spoken follow-ups

## Build

```bash
cd Samples/SceneReader && xcodegen && open SceneReader.xcodeproj
```

## Flow

1. Pick a photo.
2. In parallel: OCR + vision description. Gemma 4 narrates out loud as soon as it's ready.
3. Tap "Read aloud" to repeat, or the speaker next to the detected text to read signage only.
4. Ask follow-ups: "Where should I sit?" / "この表示は何?" — typed or by mic. The follow-up answer is spoken.
