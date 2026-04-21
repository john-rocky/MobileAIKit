# Performance

Measure first, tune second.

## Benchmark

```swift
let recorder = BenchmarkRecorder()
let runs = try await recorder.run(
    name: backend.info.name,
    backend: backend,
    prompts: ["Write a haiku.", "Explain Transformers."]
)
print(runs.map { ($0.backend, $0.tokensPerSecond, $0.firstTokenSeconds) })
```

## Golden dataset eval

```swift
let evaluator = GoldenEvaluator()
let results = try await evaluator.run(cases: [
    .init(name: "capital", input: "Capital of France?", expected: "Paris")
], backend: backend)
```

## Resource governor

```swift
await ResourceGovernor.shared.setPreferredProfile(.balanced)
await ResourceGovernor.shared.setThermalDegradation(true)

let config = await ResourceGovernor.shared.guardedConfig(base: .default)
```

Profiles:
- `.highQuality` — long outputs, lower temperature
- `.balanced` — default
- `.fast` — shorter output, smaller top-k
- `.ultraFast` — background / constrained device

## Device class

```swift
let cls = await ResourceGovernor.shared.deviceClass() // high/mid/low/constrained
```

## Model advisor

```swift
let advisor = ModelAdvisor()
let top = await advisor.recommend(from: ModelCatalog.allText).first?.descriptor
```

## UI

```swift
AIBenchmarkView(backend: backend)
AISettingsView()
AIDebugPanelView(telemetry: telemetry)
```
