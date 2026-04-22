import Foundation
import AIKit
import AIKitCoreMLLLM
import AIKitIntegration
import AIKitVision
#if canImport(UIKit)
import UIKit
#endif

/// Concrete set of checks the smoke test runs. Each check is a pure async
/// closure that either returns a short success note or throws.
enum SmokeChecks {
    static let all: [Check] = [
        Check(
            name: "Backend loaded",
            detail: "CoreMLLLMBackend advertises expected capabilities",
            runner: { backend in
                let caps = backend.info.capabilities
                let must: [BackendCapabilities] = [.textGeneration, .streaming, .vision, .chatTemplate, .toolCalling]
                for cap in must {
                    guard caps.contains(cap) else { throw SmokeError("missing capability \(cap.rawValue)") }
                }
                return "caps OK; device=\(backend.info.preferredDevice), ctx=\(backend.info.contextLength)"
            }
        ),
        Check(
            name: "AIKit.chat (one-shot text)",
            detail: "A single prompt → non-empty answer",
            runner: { backend in
                let out = try await AIKit.chat(
                    "Reply with exactly the word: PONG",
                    backend: backend,
                    config: GenerationConfig(maxTokens: 12, temperature: 0.0)
                )
                if out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw SmokeError("empty output")
                }
                return "got: \(trim(out, 40))"
            }
        ),
        Check(
            name: "AIKit.stream (token streaming)",
            detail: "Streamed deltas arrive",
            runner: { backend in
                var pieces = 0
                var accumulated = ""
                for try await delta in AIKit.stream(
                    "Count 1 to 3.",
                    backend: backend,
                    config: GenerationConfig(maxTokens: 32, temperature: 0.0)
                ) {
                    pieces += 1
                    accumulated += delta
                    if pieces >= 128 { break }
                }
                if pieces == 0 { throw SmokeError("no deltas received") }
                return "\(pieces) chunks; \(trim(accumulated, 40))"
            }
        ),
        Check(
            name: "ChatSession (multi-turn)",
            detail: "Session keeps history across turns",
            runner: { backend in
                let session = await MainActor.run {
                    ChatSession(backend: backend, systemPrompt: "Be very terse.")
                }
                _ = try await session.send("Remember: my name is Test.")
                let reply = try await session.send("What is my name?")
                let lower = reply.content.lowercased()
                if !lower.contains("test") {
                    throw SmokeError("lost context: \(trim(reply.content, 50))")
                }
                return "remembered name; \(trim(reply.content, 50))"
            }
        ),
        Check(
            name: "AIKit.extract (structured output)",
            detail: "Prompt-based JSON extraction via schema",
            runner: { backend in
                struct Person: Codable { let name: String; let age: Int }
                let schema = JSONSchema.object(
                    properties: ["name": .string(), "age": .integer()],
                    required: ["name", "age"]
                )
                let p: Person = try await AIKit.extract(
                    Person.self,
                    from: "Taro is 29 years old.",
                    schema: schema,
                    instruction: "Extract the person's name and age.",
                    backend: backend
                )
                if p.name.lowercased().contains("taro") == false || p.age != 29 {
                    throw SmokeError("wrong values: \(p.name), \(p.age)")
                }
                return "\(p.name), \(p.age)"
            }
        ),
        Check(
            name: "AIKit.askWithTools (prompt-based tool call)",
            detail: "Model invokes a fake calculator tool via CoreMLLLMBackend's JSON protocol",
            runner: { backend in
                let registry = ToolRegistry()
                let counter = CallCounter()
                await registry.setAuditHandler { _, _, _ in counter.increment() }
                let tool = TypedTool<CalcArgs, CalcResult>(
                    spec: ToolSpec(
                        name: "add_two_numbers",
                        description: "Returns the sum of two integers.",
                        parameters: .object(
                            properties: [
                                "a": .integer(),
                                "b": .integer()
                            ],
                            required: ["a", "b"]
                        )
                    )
                ) { args in
                    CalcResult(sum: args.a + args.b)
                }
                await registry.register(tool)
                let out = try await AIKit.askWithTools(
                    "What is 7 + 5? Use the add_two_numbers tool.",
                    tools: registry,
                    backend: backend
                )
                let n = counter.value
                if n == 0 {
                    throw SmokeError("tool never executed. reply: \(trim(out, 80))")
                }
                return "tool fired \(n)×; reply: \(trim(out, 60))"
            }
        ),
        Check(
            name: "RAGPipeline (HashingEmbedder)",
            detail: "Index a snippet, retrieve, answer with citations",
            runner: { backend in
                let embedder = HashingEmbedder(dimension: 256)
                let rag = RAGPipeline(embedder: embedder)
                try await rag.ingest(
                    text: "The office Wi-Fi password is `sakura-2026`. It rotates every quarter.",
                    source: "memo.txt"
                )
                let result = try await rag.ask("What is the Wi-Fi password?", backend: backend)
                if result.citations.isEmpty {
                    throw SmokeError("no citations")
                }
                return "cited \(result.citations.count); ans: \(trim(result.answer, 40))"
            }
        ),
        Check(
            name: "DatabaseMemoryStore",
            detail: "Persisted memory round-trips via SQLite",
            runner: { backend in
                let embedder = HashingEmbedder(dimension: 128)
                let memory = try DatabaseMemoryStore(embedder: embedder)
                let record = MemoryRecord(
                    kind: .longTerm,
                    text: "Red means stop; green means go."
                )
                try await memory.store(record)
                let hits = try await memory.retrieve(query: "what does red mean", limit: 3)
                if hits.isEmpty { throw SmokeError("no retrieved records") }
                return "retrieved \(hits.count) record(s)"
            }
        ),
        Check(
            name: "AIKit.classify (label enum)",
            detail: "Zero-shot classification via extract() under the hood",
            runner: { backend in
                enum Sentiment: String, CaseIterable, Sendable { case positive, negative, neutral }
                let label = try await AIKit.classify(
                    "I loved every minute of it.",
                    labels: Sentiment.self,
                    backend: backend
                )
                return "got .\(label.rawValue)"
            }
        ),
        Check(
            name: "AIKit.analyzeImage (vision)",
            detail: "Runs a 1×1 generated JPEG through the VLM path",
            runner: { backend in
                #if canImport(UIKit)
                guard let jpeg = tinyImageJPEGData() else {
                    throw SmokeError("could not build test image")
                }
                let attach = ImageAttachment(jpeg: jpeg)
                let answer = try await AIKit.analyzeImage(
                    attach,
                    prompt: "Describe this image in a single short phrase.",
                    backend: backend
                )
                if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw SmokeError("empty vision reply")
                }
                return trim(answer, 60)
                #else
                throw SmokeError("UIKit unavailable — run on iOS")
                #endif
            }
        ),
        Check(
            name: "AIKit.ocr (Vision framework)",
            detail: "Renders a bitmap with text, checks OCR reads it back",
            runner: { _ in
                #if canImport(UIKit)
                guard let jpeg = textImageJPEGData(text: "Hello 123") else {
                    throw SmokeError("could not render text image")
                }
                let result = try await AIKit.ocr(image: ImageAttachment(jpeg: jpeg))
                let text = result.text.lowercased()
                if !text.contains("hello") {
                    throw SmokeError("OCR missed text: \(trim(result.text, 40))")
                }
                return "read: \(trim(result.text, 50))"
                #else
                throw SmokeError("UIKit unavailable")
                #endif
            }
        ),
        Check(
            name: "BackendRouter fallback",
            detail: "Router picks the healthy backend when one fails",
            runner: { backend in
                final class AlwaysFail: AIBackend, @unchecked Sendable {
                    let info = BackendInfo(name: "fail", version: "0", capabilities: [.textGeneration], contextLength: 4, preferredDevice: "none")
                    var isLoaded: Bool { get async { true } }
                    func load() async throws { throw AIError.modelLoadFailed("test failure") }
                    func unload() async {}
                    func generate(messages: [Message], tools: [ToolSpec], config: GenerationConfig) async throws -> GenerationResult {
                        throw AIError.modelLoadFailed("test failure")
                    }
                    func stream(messages: [Message], tools: [ToolSpec], config: GenerationConfig) -> AsyncThrowingStream<GenerationChunk, Error> {
                        AsyncThrowingStream { $0.finish(throwing: AIError.modelLoadFailed("test failure")) }
                    }
                    func tokenCount(for messages: [Message]) async throws -> Int { 0 }
                }
                let router = BackendRouter(backends: [AlwaysFail(), backend])
                let out = try await router.generate(
                    messages: [.user("Say OK.")],
                    tools: [],
                    config: GenerationConfig(maxTokens: 8, temperature: 0.0)
                )
                return "fallback OK: \(trim(out.message.content, 40))"
            }
        ),
    ]
}

// MARK: - Helpers

struct SmokeError: LocalizedError { let message: String
    init(_ m: String) { self.message = m }
    var errorDescription: String? { message }
}

struct CalcArgs: Codable, Sendable { let a: Int; let b: Int }
struct CalcResult: Codable, Sendable { let sum: Int }

/// Lock-guarded counter used by the tool-calling check's audit handler.
final class CallCounter: @unchecked Sendable {
    private var _value = 0
    private let lock = NSLock()
    func increment() { lock.withLock { _value += 1 } }
    var value: Int { lock.withLock { _value } }
}

private func trim(_ s: String, _ max: Int) -> String {
    let t = s.replacingOccurrences(of: "\n", with: " ")
    if t.count <= max { return t }
    return String(t.prefix(max)) + "…"
}

#if canImport(UIKit)
private func tinyImageJPEGData() -> Data? {
    let size = CGSize(width: 32, height: 32)
    let renderer = UIGraphicsImageRenderer(size: size)
    let img = renderer.image { ctx in
        UIColor.systemOrange.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
    return img.jpegData(compressionQuality: 0.8)
}

private func textImageJPEGData(text: String) -> Data? {
    let size = CGSize(width: 240, height: 80)
    let renderer = UIGraphicsImageRenderer(size: size)
    let img = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 36),
            .foregroundColor: UIColor.black
        ]
        (text as NSString).draw(at: CGPoint(x: 12, y: 20), withAttributes: attrs)
    }
    return img.jpegData(compressionQuality: 0.9)
}
#endif
