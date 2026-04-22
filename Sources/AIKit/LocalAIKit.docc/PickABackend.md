# Pick a Backend

AIKit currently ships one runtime: `CoreMLLLMBackend`, a thin wrapper around
[john-rocky/coreml-llm](https://github.com/john-rocky/coreml-llm). It targets
the Apple Neural Engine and supports multimodal (text + image + audio) input.

Other runtimes (MLX, llama.cpp, Foundation Models, generic CoreML) are out of
scope right now so the kit stays small and the dependency graph stays clean.
Bring your own by conforming to ``AIBackend`` if you need one.

## CoreML-LLM (default)

```swift
import AIKitCoreMLLLM

let backend = CoreMLLLMBackend(model: .gemma4e2b)
try await backend.load()
```

Hold the backend once (e.g. via ``AIBackendHost``) — creating a new instance
on every call will reload the model.

## Router with fallback

`BackendRouter` can still be used if you construct multiple `AIBackend`
instances yourself (e.g. two different CoreML-LLM models):

```swift
let router = BackendRouter(backends: [
    CoreMLLLMBackend(model: .gemma4e2b),
    CoreMLLLMBackend(model: .gemma4e4b)
])
```

## Capability discovery

```swift
if backend.info.capabilities.contains(.vision) {
    // attach images
}
```
