import CoreLocation

/// Requests a single GPS fix and publishes the result via a callback.
/// The permission dialog is shown automatically on first call; subsequent
/// calls reuse the already-granted authorization.
@MainActor
final class LocationService: NSObject {

    private(set) var coordinate: CLLocationCoordinate2D?

    /// Called on the main actor whenever a new location fix arrives.
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Request a fresh single-shot location fix.
    /// Shows the system permission dialog if not yet determined.
    func requestLocation() {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break  // denied / restricted — GPS unavailable, arc falls back to cached coord
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.coordinate = coord
            self.onLocationUpdate?(coord)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedAlways else { return }
        manager.requestLocation()
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Non-critical: GPS failure is graceful — the map still works without an arc.
    }
}
