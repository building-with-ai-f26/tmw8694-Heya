import Foundation
import CoreMotion
import CoreLocation

// MARK: - Bump detector

/// Notices a sharp bump, like two phones tapped together.
final class BumpDetector {
    private let manager = CMMotionManager()
    private var lastBump = Date.distantPast

    /// Called on the main thread.
    var onBump: (() -> Void)?

    /// How hard a bump must be, in g. Lower = more sensitive.
    var threshold: Double = 1.0

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let a = motion?.userAcceleration else { return }
            let force = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            if force > self.threshold, Date().timeIntervalSince(self.lastBump) > 1.5 {
                self.lastBump = Date()
                self.onBump?()
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Locator

/// Gets one location fix when you bump phones (only while Heya is open).
final class Locator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: [(CLLocation?) -> Void] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation(_ completion: @escaping (CLLocation?) -> Void) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            pending.append(completion)
            manager.requestLocation()
        case .notDetermined:
            pending.append(completion)
            manager.requestWhenInUseAuthorization()
        default:
            completion(nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !pending.isEmpty else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            break
        default:
            flush(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        flush(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        flush(nil)
    }

    private func flush(_ location: CLLocation?) {
        let callbacks = pending
        pending = []
        callbacks.forEach { $0(location) }
    }

    /// A friendly name for a spot: a park or venue if known, otherwise the street.
    static func placeName(for location: CLLocation, completion: @escaping (String?) -> Void) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            let mark = placemarks?.first
            completion(mark?.areasOfInterest?.first ?? mark?.name ?? mark?.thoroughfare ?? mark?.locality)
        }
    }
}

// MARK: - Storage

/// Real friends and moments, saved as a file on this phone only.
struct SavedData: Codable {
    var friends: [Friend] = []
    var moments: [Moment] = []
}

enum Storage {
    static var url: URL {
        URL.documentsDirectory.appending(path: "heya.json")
    }

    static func load() -> SavedData {
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(SavedData.self, from: data) else {
            return SavedData()
        }
        return saved
    }

    static func save(_ saved: SavedData) {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
