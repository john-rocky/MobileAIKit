import Foundation
import AIKit

enum ToolCallingExample {
    @MainActor
    static func run(backend: any AIBackend) async throws -> String {
        let registry = ToolRegistry()
        struct WeatherArgs: Decodable { let city: String }
        struct WeatherOut: Encodable { let city: String; let temperatureC: Double; let summary: String }

        await registry.register(
            name: "get_weather",
            description: "Look up the current weather for a city.",
            parameters: .object(
                properties: ["city": .string(description: "City name")],
                required: ["city"]
            )
        ) { (args: WeatherArgs) async throws -> WeatherOut in
            return WeatherOut(city: args.city, temperatureC: 18.5, summary: "Partly cloudy")
        }

        let session = ChatSession(
            backend: backend,
            systemPrompt: "Call get_weather when the user asks about weather.",
            tools: await registry.specs(),
            toolRegistry: registry
        )
        let response = try await session.send("What's the weather in Tokyo?")
        return response.content
    }
}
