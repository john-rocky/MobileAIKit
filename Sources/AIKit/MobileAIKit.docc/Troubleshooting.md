# Troubleshooting

## `AIError.modelLoadFailed`
- Confirm the model file exists at the given URL.
- For GGUF: verify the file isn't truncated; re-download if `ModelCache.verifyChecksum` fails.
- For MLX: ensure the Hugging Face repo id is correct and network is reachable on first load.
- For CoreML: if the file is `.mlpackage`, AIKit auto-compiles to `.mlmodelc` — this can take a minute on first run.

## `AIError.tokenizerNotFound`
- Pass either `tokenizerRepoId` or a `tokenizerDirectory` to `CoreMLBackend.Configuration`.
- On first network call the tokenizer is cached locally; offline use works after that.

## Slow first token
- Cold load dominates. Preload with `try await backend.load()` at app launch.
- Reduce `contextLength` if you don't need the whole window.
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

## Crashes with "couldn't find framework"
- `AIKitFoundationModels` needs iOS 26 / macOS 26.
- `AIKitMLX` needs Apple Silicon or iOS 17+.
- Conditional imports (`#if canImport(...)`) gate optional features.

## Memory corruption / missing data
- Use `DatabaseMemoryStore` instead of `PersistentMemoryStore` for durability (WAL mode).
- For Codable imports, ensure the JSON was produced by `exportAll()`.
