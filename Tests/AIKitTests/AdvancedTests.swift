import XCTest
@testable import AIKit

final class AdvancedTests: XCTestCase {

    func testRAGPipelineReturnsCitations() async throws {
        let rag = RAGPipeline(embedder: HashingEmbedder(dimension: 128))
        try await rag.ingest(text: "Matcha is a type of green tea.", source: "tea-notes")
        try await rag.ingest(text: "Espresso is a concentrated coffee.", source: "coffee-notes")

        let backend = MockBackend { messages in
            let last = messages.last?.content ?? ""
            return "matcha" + (last.contains("matcha") ? " (from tea-notes)" : "")
        }
        let answer = try await rag.ask("What is matcha?", backend: backend)
        XCTAssertFalse(answer.citations.isEmpty)
        XCTAssertTrue(answer.citations.contains { $0.source == "tea-notes" })
    }

    func testChecklistOutputSchemaDecodesRepairedJSON() throws {
        let raw = """
        Here you go:
        {"title":"Groceries","items":[{"title":"Milk","category":"dairy","importance":0.8}]}
        """
        let decoded = try StructuredDecoder().decode(ChecklistOutput.self, from: raw)
        XCTAssertEqual(decoded.title, "Groceries")
        XCTAssertEqual(decoded.items.count, 1)
    }

    func testTokenBudgetPlannerDropsOldMessages() async throws {
        let backend = MockBackend { _ in "" }
        let planner = TokenBudgetPlanner(backend: backend, budget: TokenBudget(total: 100, reservedForSystem: 20, reservedForOutput: 60))
        let history = (0..<20).map { Message.user(String(repeating: "x", count: 100)) }
        let truncated = try await planner.truncate(messages: history)
        XCTAssertLessThan(truncated.count, history.count)
    }

    func testBatteryBudgetFallsBackToProfile() {
        let profile = BatteryBudget.recommendedProfile()
        XCTAssertTrue([.highQuality, .balanced, .fast, .ultraFast].contains(profile))
    }

    func testDuckDuckGoParserExtractsResults() {
        let html = """
        <div class="result"><a class="result__a" href="https://example.com/first">First Title</a>
        <a class="result__snippet">First snippet.</a></div>
        <div class="result"><a class="result__a" href="/l/?uddg=https%3A%2F%2Fexample.com%2Fsecond">Second Title</a>
        <a class="result__snippet">Second snippet.</a></div>
        """
        let results = DuckDuckGoSearchProvider.parse(html: html, limit: 10)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "First Title")
        XCTAssertEqual(results[1].url, "https://example.com/second")
    }

    func testHierarchicalChunkerProducesMultipleLevels() {
        let chunker = HierarchicalChunker(topLevelChars: 200, midLevelChars: 80, leafChars: 30)
        let text = String(repeating: "Lorem ipsum dolor sit amet. ", count: 20)
        let chunks = chunker.chunk(text, source: "test")
        let levels = Set(chunks.compactMap { $0.metadata["level"] })
        XCTAssertTrue(levels.contains("top"))
        XCTAssertTrue(levels.contains("mid"))
        XCTAssertTrue(levels.contains("leaf"))
    }

    func testBackendRouterFallsBackOnError() async throws {
        let failing = MockBackend(shouldFail: true) { _ in "" }
        let working = MockBackend { _ in "hello" }
        let router = BackendRouter(backends: [failing, working])
        let result = try await router.generate(messages: [.user("hi")], tools: [], config: .default)
        XCTAssertEqual(result.message.content, "hello")
    }
}

final class MockBackend: AIBackend, @unchecked Sendable {
    let info = BackendInfo(
        name: "mock", version: "1",
        capabilities: [.textGeneration, .streaming, .tokenization],
        contextLength: 4096, preferredDevice: "cpu"
    )
    var isLoaded: Bool { get async { true } }
    let respond: @Sendable ([Message]) -> String
    let shouldFail: Bool

    init(shouldFail: Bool = false, respond: @Sendable @escaping ([Message]) -> String) {
        self.shouldFail = shouldFail
        self.respond = respond
    }

    func load() async throws {}
    func unload() async {}

    func generate(messages: [Message], tools: [ToolSpec], config: GenerationConfig) async throws -> GenerationResult {
        if shouldFail { throw AIError.generationFailed("mock fail") }
        return GenerationResult(
            message: .assistant(respond(messages)),
            usage: GenerationUsage(),
            finishReason: .stop
        )
    }

    func stream(messages: [Message], tools: [ToolSpec], config: GenerationConfig) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                if shouldFail { continuation.finish(throwing: AIError.generationFailed("mock fail")); return }
                let text = respond(messages)
                for ch in text {
                    continuation.yield(GenerationChunk(delta: String(ch)))
                }
                continuation.yield(GenerationChunk(finished: true, finishReason: .stop))
                continuation.finish()
            }
        }
    }

    func tokenCount(for messages: [Message]) async throws -> Int {
        messages.map(\.content).joined(separator: " ").count / 4
    }
}
