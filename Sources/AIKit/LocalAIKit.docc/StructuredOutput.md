# Structured Output

Turn free-form LLM responses into typed Swift values.

## Codable extract

```swift
struct Contact: Codable { let name: String; let email: String? }

let schema: JSONSchema = .object(
    properties: ["name": .string(), "email": .string(format: "email")],
    required: ["name"]
)
let contact: Contact = try await AIKit.extract(
    Contact.self, from: text, schema: schema, instruction: "Extract contact.", backend: backend
)
```

## Classify into an enum

```swift
enum Priority: String, CaseIterable { case low, medium, high }
let p = try await AIKit.classify(subject, labels: Priority.self, backend: backend)
```

## Retry until valid JSON

```swift
let result: MyType = try await ConstrainedDecoder(maxAttempts: 3).decode(
    MyType.self, schema: schema, backend: backend, messages: [.user("...")]
)
```

## Best-of-N

```swift
let best = try await MultiCandidate.parallelBestOfN(
    backend: backend,
    messages: [.user("Write a haiku.")],
    n: 3
) { candidate in
    Double(candidate.count)
}
```

## Streaming structured partials

```swift
let decoder = StreamingStructuredDecoder<MyType>()
let stream = backend.stream(messages: ..., tools: [], config: .deterministic)
for try await partial in decoder.stream(from: stream) {
    updateUI(partial)
}
```
