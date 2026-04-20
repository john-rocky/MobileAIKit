import Foundation
import AIKit
#if canImport(MapKit)
import MapKit

public enum MapKitBridge {
    public static func searchPlacesTool() -> any Tool {
        let spec = ToolSpec(
            name: "search_places",
            description: "Search for places/POIs near a coordinate or by text.",
            parameters: .object(
                properties: [
                    "query": .string(),
                    "latitude": .number(),
                    "longitude": .number(),
                    "radius_meters": .number(minimum: 10, maximum: 50000)
                ],
                required: ["query"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable {
            let query: String; let latitude: Double?; let longitude: Double?; let radius_meters: Double?
        }
        struct Place: Encodable {
            let name: String; let latitude: Double; let longitude: Double; let address: String?
        }
        return TypedTool(spec: spec) { (args: Args) async throws -> [Place] in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = args.query
            if let lat = args.latitude, let lon = args.longitude {
                let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let span = MKCoordinateRegion(center: center, latitudinalMeters: args.radius_meters ?? 2000, longitudinalMeters: args.radius_meters ?? 2000)
                request.region = span
            }
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems.prefix(10).map { item in
                Place(
                    name: item.name ?? "",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude,
                    address: item.placemark.title
                )
            }
        }
    }

    public static func directionsTool() -> any Tool {
        let spec = ToolSpec(
            name: "get_directions",
            description: "Get driving directions from A to B.",
            parameters: .object(
                properties: [
                    "fromLat": .number(),
                    "fromLon": .number(),
                    "toLat": .number(),
                    "toLon": .number(),
                    "mode": .string(enumValues: ["driving", "walking", "transit"])
                ],
                required: ["fromLat", "fromLon", "toLat", "toLon"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable {
            let fromLat: Double; let fromLon: Double; let toLat: Double; let toLon: Double; let mode: String?
        }
        struct Out: Encodable { let distanceMeters: Double; let expectedTravelTime: Double; let steps: [String] }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: args.fromLat, longitude: args.fromLon)))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: args.toLat, longitude: args.toLon)))
            switch args.mode ?? "driving" {
            case "walking": request.transportType = .walking
            case "transit": request.transportType = .transit
            default: request.transportType = .automobile
            }
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                throw AIError.resourceUnavailable("No route found")
            }
            return Out(
                distanceMeters: route.distance,
                expectedTravelTime: route.expectedTravelTime,
                steps: route.steps.map { $0.instructions }
            )
        }
    }
}
#endif
