import Foundation
import AIKit
#if canImport(WeatherKit)
import WeatherKit
import CoreLocation
#endif

#if canImport(WeatherKit)
public final class WeatherKitBridge: Sendable {
    public let service = WeatherService.shared
    public init() {}

    public func currentWeatherTool() -> any Tool {
        let spec = ToolSpec(
            name: "current_weather",
            description: "Fetch current weather via WeatherKit for a coordinate.",
            parameters: .object(
                properties: [
                    "latitude": .number(),
                    "longitude": .number()
                ],
                required: ["latitude", "longitude"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let latitude: Double; let longitude: Double }
        struct Out: Encodable {
            let temperatureCelsius: Double
            let apparentTemperatureCelsius: Double
            let humidity: Double
            let conditionDescription: String
            let windKph: Double
            let uvIndex: Int
            let isDaylight: Bool
        }
        return TypedTool(spec: spec) { [service] (args: Args) async throws -> Out in
            let location = CLLocation(latitude: args.latitude, longitude: args.longitude)
            let weather = try await service.weather(for: location)
            let c = weather.currentWeather
            return Out(
                temperatureCelsius: c.temperature.converted(to: .celsius).value,
                apparentTemperatureCelsius: c.apparentTemperature.converted(to: .celsius).value,
                humidity: c.humidity,
                conditionDescription: c.condition.description,
                windKph: c.wind.speed.converted(to: .kilometersPerHour).value,
                uvIndex: c.uvIndex.value,
                isDaylight: c.isDaylight
            )
        }
    }

    public func dailyForecastTool(days: Int = 7) -> any Tool {
        let spec = ToolSpec(
            name: "daily_forecast",
            description: "Fetch a multi-day daily weather forecast.",
            parameters: .object(
                properties: [
                    "latitude": .number(),
                    "longitude": .number(),
                    "days": .integer(minimum: 1, maximum: 10)
                ],
                required: ["latitude", "longitude"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let latitude: Double; let longitude: Double; let days: Int? }
        struct Day: Encodable {
            let date: String
            let highC: Double
            let lowC: Double
            let condition: String
            let precipitationChance: Double
        }
        return TypedTool(spec: spec) { [service] (args: Args) async throws -> [Day] in
            let location = CLLocation(latitude: args.latitude, longitude: args.longitude)
            let weather = try await service.weather(for: location)
            let iso = ISO8601DateFormatter()
            return weather.dailyForecast.forecast.prefix(args.days ?? days).map { d in
                Day(
                    date: iso.string(from: d.date),
                    highC: d.highTemperature.converted(to: .celsius).value,
                    lowC: d.lowTemperature.converted(to: .celsius).value,
                    condition: d.condition.description,
                    precipitationChance: d.precipitationChance
                )
            }
        }
    }
}
#endif
