import Foundation
import AIKit
#if canImport(CoreLocation)
import CoreLocation

public final class LocationBridge: NSObject, @unchecked Sendable, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    public override init() {
        super.init()
        manager.delegate = self
    }

    public func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        await withCheckedContinuation { cont in
            authContinuation = cont
            manager.requestWhenInUseAuthorization()
        }
    }

    public func currentLocation(accuracy: CLLocationAccuracy = kCLLocationAccuracyNearestTenMeters) async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            locationContinuation = cont
            manager.desiredAccuracy = accuracy
            manager.requestLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            locationContinuation?.resume(returning: loc)
        } else {
            locationContinuation?.resume(throwing: AIError.resourceUnavailable("No location"))
        }
        locationContinuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authContinuation?.resume(returning: manager.authorizationStatus)
        authContinuation = nil
    }

    public func currentLocationTool() -> any Tool {
        let spec = ToolSpec(
            name: "current_location",
            description: "Get the user's current latitude and longitude.",
            parameters: .object(properties: [:], required: []),
            requiresApproval: true,
            sideEffectFree: true
        )
        struct Args: Decodable {}
        struct Out: Encodable {
            let latitude: Double; let longitude: Double; let altitude: Double; let timestamp: String
        }
        return TypedTool(spec: spec) { (_: Args) async throws -> Out in
            let loc = try await self.currentLocation()
            return Out(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.altitude,
                timestamp: ISO8601DateFormatter().string(from: loc.timestamp)
            )
        }
    }
}
#endif
