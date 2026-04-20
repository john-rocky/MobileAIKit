import XCTest
@testable import AIKit

final class AIKitTests: XCTestCase {

    func testStructuredDecoderFindsJSONInCodeFence() throws {
        struct Person: Codable, Equatable { let name: String; let age: Int }
        let raw = """
        Sure! Here is the JSON:
        ```json
        {"name": "Ada", "age": 36}
        ```
        """
        let decoded = try StructuredDecoder().decode(Person.self, from: raw)
        XCTAssertEqual(decoded, Person(name: "Ada", age: 36))
    }

    func testStructuredDecoderRepairsTruncatedObject() throws {
        struct Person: Codable, Equatable { let name: String; let age: Int }
        let raw = "{\"name\": \"Ada\", \"age\": 36"
        let decoded = try StructuredDecoder().decode(Person.self, from: raw)
        XCTAssertEqual(decoded.name, "Ada")
    }

    func testJSONSchemaSerialization() throws {
        let schema: JSONSchema = .object(
            properties: [
                "name": .string(description: "Name"),
                "age": .integer(minimum: 0)
            ],
            required: ["name"]
        )
        let data = try schema.jsonData()
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["type"] as? String, "object")
    }

    func testHashingEmbedderDeterministic() async throws {
        let embedder = HashingEmbedder(dimension: 32)
        let a = try await embedder.embed("hello world")
        let b = try await embedder.embed("hello world")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 32)
    }

    func testVectorIndexReturnsRelevantDocs() async throws {
        let embedder = HashingEmbedder(dimension: 256)
        let index = VectorIndex(embedder: embedder)
        try await index.add([
            Chunk(text: "Swift actors isolate mutable state.", source: "doc1", startOffset: 0, endOffset: 40),
            Chunk(text: "The Eiffel tower is in Paris.", source: "doc2", startOffset: 0, endOffset: 30),
            Chunk(text: "Actors prevent data races in concurrency.", source: "doc3", startOffset: 0, endOffset: 40)
        ])
        let results = try await index.search(query: "Swift concurrency actors", limit: 2)
        XCTAssertGreaterThan(results.count, 0)
    }

    func testToolRegistryExecutesTypedTool() async throws {
        let registry = ToolRegistry()
        struct Args: Decodable { let a: Int; let b: Int }
        struct Out: Encodable { let sum: Int }
        await registry.register(
            name: "sum",
            description: "Sum two ints",
            parameters: .object(properties: ["a": .integer(), "b": .integer()], required: ["a", "b"])
        ) { (args: Args) async throws -> Out in
            Out(sum: args.a + args.b)
        }
        let result = try await registry.execute(call: ToolCall(id: "1", name: "sum", arguments: "{\"a\": 3, \"b\": 4}"))
        XCTAssertTrue(result.text.contains("\"sum\":7") || result.text.contains("\"sum\" : 7"))
    }

    func testInMemoryStoreRetrievesByKeyword() async throws {
        let store = InMemoryStore()
        try await store.store(MemoryRecord(kind: .longTerm, text: "User loves matcha and runs marathons."))
        let results = try await store.retrieve(query: "matcha", limit: 5)
        XCTAssertFalse(results.isEmpty)
    }

    func testChunkerRespectsLimit() {
        let chunker = Chunker(maxCharacters: 50, overlap: 10, respectParagraphs: false)
        let text = String(repeating: "x", count: 200)
        let chunks = chunker.chunk(text, source: "test")
        XCTAssertGreaterThan(chunks.count, 1)
        for c in chunks { XCTAssertLessThanOrEqual(c.text.count, 50) }
    }

    func testChatTemplateRoundTripsRoles() {
        let template = ChatTemplate.llama3
        let rendered = template.render([
            .system("be nice"),
            .user("hi"),
            .assistant("hello")
        ])
        XCTAssertTrue(rendered.contains("system"))
        XCTAssertTrue(rendered.contains("user"))
        XCTAssertTrue(rendered.contains("assistant"))
    }
}
