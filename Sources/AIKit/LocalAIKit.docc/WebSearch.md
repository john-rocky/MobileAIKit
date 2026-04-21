# Web Search

Real providers, not stubs.

## DuckDuckGo (no API key)

```swift
let results = try await AIKit.searchWeb("latest SwiftUI news")
```

## Brave / Bing (API key)

```swift
let brave = BraveSearchProvider(apiKey: ProcessInfo.processInfo.environment["BRAVE_KEY"]!)
let bing  = BingSearchProvider(apiKey: ProcessInfo.processInfo.environment["BING_KEY"]!)
let hits = try await brave.search(query: "mobile AI kit", limit: 5)
```

## Agentic browse-and-ask

```swift
let answer = try await AIKit.browseAndAsk(
    "Summarise today's top AI news and cite URLs.",
    backend: backend
)
```

## As a tool

```swift
let registry = ToolRegistry()
await registry.register(WebSearch.tool(provider: DuckDuckGoSearchProvider()))
await registry.register(WebPageReader.readerTool())
```
