# Tool Calling

Expose Swift async functions as tools the model can invoke.

## Register a typed tool

```swift
struct WeatherArgs: Decodable { let city: String }
struct WeatherOut: Encodable { let tempC: Double; let summary: String }

let registry = ToolRegistry(cache: ToolResultCache(), retry: ToolRetry())
await registry.register(
    name: "get_weather",
    description: "Look up current weather.",
    parameters: .object(
        properties: ["city": .string(description: "City name")],
        required: ["city"]
    )
) { (args: WeatherArgs) async throws -> WeatherOut in
    WeatherOut(tempC: 22.1, summary: "Sunny")
}
```

## Let the model use it

```swift
let answer = try await AIKit.askWithTools(
    "What's the weather in Tokyo?",
    tools: registry,
    backend: backend
)
```

## Approval gate for side-effectful tools

```swift
let registry = ToolRegistry { spec, argumentData in
    await confirm("Allow \(spec.name)?")
}
```

## Built-in tools

- `WebSearch.tool(provider: DuckDuckGoSearchProvider())`
- `WebPageReader.readerTool()`
- `PDFExtractor.readerTool()`
- `EventKitBridge().createEventTool()`
- `ContactsBridge().searchTool()`
- `LocationBridge().currentLocationTool()`
- `MapKitBridge.searchPlacesTool()`
- `HealthKitBridge().recentStepCountTool()`
- `NotificationBridge.scheduleTool()`
- `CoreMLClassifierTool.asTool()`

## Multi-step plans

```swift
let planner = PlanExecutor(backend: backend, tools: registry)
let (plan, results) = try await planner.run(goal: "Find highest-rated ramen nearby, then create a calendar event.")
```
