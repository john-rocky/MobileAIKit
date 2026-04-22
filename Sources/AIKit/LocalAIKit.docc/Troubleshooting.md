# Troubleshooting

## `AIError.modelLoadFailed`
- Confirm the `.mlpackage` / `.mlmodelc` exists at the given URL (or the `ModelDownloader` entry has finished downloading).
- First-run ANE warm-up can take 10–30 seconds — wire `CoreMLLLMBackend.progressHandler` to show status to the user.

## `AIError.downloadFailed`
- Retry on Wi-Fi; Hugging Face weight downloads are large.
- Use `backend.download()` during onboarding to pre-fetch before the user hits the chat UI.

## Slow first token
- Cold load dominates. Preload with `try await backend.load()` at app launch.
- Reduce `config.maxTokens` if you don't need a long reply.
- Use `ResourceGovernor.shared.guardedConfig(base:)` to auto-scale quality.

## Thermal throttling on device
- Check `await ResourceGovernor.shared.thermalState`.
- Enable `thermalDegradationEnabled` to automatically drop to `.fast`.

## JSON decoding fails
- Let `StructuredDecoder` do its repair pass — that's on by default in `AIKit.extract`.
- Use `ConstrainedDecoder` for three-strike retry with schema feedback.

## Tool call loops forever
- Bound iterations via `AIKit.askWithTools` (already capped at 8).
- Add `dryRun = true` on the `ToolRegistry` to inspect args without executing.

## Memory corruption / missing data
- Use `DatabaseMemoryStore` instead of `PersistentMemoryStore` for durability (WAL mode).
- For Codable imports, ensure the JSON was produced by `exportAll()`.
