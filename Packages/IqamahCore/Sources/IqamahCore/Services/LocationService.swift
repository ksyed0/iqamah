import Foundation
import CoreLocation
import Combine

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

@MainActor
public class LocationService: NSObject, ObservableObject {
    @Published public var currentLocation: CLLocationCoordinate2D?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var locationError: String?
    @Published public var isLoading = false

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var pendingLocationRequest = false

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }

    public func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func requestLocation() {
        isLoading = true
        locationError = nil

        let currentStatus = locationManager.authorizationStatus
        authorizationStatus = currentStatus

        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            pendingLocationRequest = true
            requestPermission()
        case .denied, .restricted:
            isLoading = false
            locationError = "Location access denied. Please enable in System Settings."
        @unknown default:
            isLoading = false
            locationError = "Unknown location authorization status."
        }
    }

    public func requestLocationAsync() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: NSError(
                    domain: "LocationService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]
                ))
                return
            }
            Task { @MainActor in
                self.locationContinuation = continuation
                self.requestLocation()
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    public nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            isLoading = false
            pendingLocationRequest = false
            if let location = locations.first {
                currentLocation = location.coordinate
                locationContinuation?.resume(returning: location.coordinate)
                locationContinuation = nil
            }
        }
    }

    public nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isLoading = false
            pendingLocationRequest = false
            locationError = error.localizedDescription
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }

    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            authorizationStatus = status

            switch status {
            case .authorizedWhenInUse, .authorizedAlways, .authorized:
                if pendingLocationRequest || locationContinuation != nil {
                    pendingLocationRequest = false
                    locationManager.requestLocation()
                }
            case .denied, .restricted:
                isLoading = false
                pendingLocationRequest = false
                locationError = "Location access denied. Please enable in System Settings."
                locationContinuation?.resume(throwing: NSError(
                    domain: "LocationService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Location access denied"]
                ))
                locationContinuation = nil
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}
