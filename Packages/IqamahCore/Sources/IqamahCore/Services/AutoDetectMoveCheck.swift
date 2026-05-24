import CoreLocation
import Foundation

/// BUG-0069: launch-time check that asks whether the user has moved more than
/// 25 km from their saved city. Pure logic — UI sits on top of it.
///
/// Each platform's app entry point calls `evaluate(_:savedCity:)` with the
/// freshly-resolved GPS coordinate. If the result is `.shouldPrompt`, the
/// caller surfaces a non-modal alert offering to switch the saved city.
/// We never auto-switch — the user's manual selection must always win.
public enum AutoDetectMoveCheck {
    /// Outcome of evaluating a freshly-resolved GPS coordinate against the saved city.
    public enum Outcome: Equatable {
        /// Auto-detect is disabled, the user has not yet completed setup, or no saved city.
        case skip
        /// The user is still within `SettingsManager.autoDetectThresholdMeters` of their saved city.
        case withinThreshold(distanceMeters: CLLocationDistance)
        /// The user has moved beyond the threshold — caller should present the switch prompt.
        case shouldPrompt(distanceMeters: CLLocationDistance, savedCityName: String)
    }

    /// Pure decision function. Caller is responsible for fetching the GPS coordinate
    /// and presenting any UI.
    public static func evaluate(
        settings: SettingsManager,
        currentCoordinate: CLLocationCoordinate2D
    ) -> Outcome {
        guard settings.hasCompletedSetup, settings.autoDetectOnMove else { return .skip }
        guard let saved = settings.loadCity() else { return .skip }
        let distance = SettingsManager.distance(from: saved.coordinate, to: currentCoordinate)
        if distance > SettingsManager.autoDetectThresholdMeters {
            return .shouldPrompt(distanceMeters: distance, savedCityName: saved.name)
        }
        return .withinThreshold(distanceMeters: distance)
    }

    /// Build a user-facing kilometer string (e.g. "27 km") from a meters distance.
    public static func formatKilometers(_ meters: CLLocationDistance) -> String {
        let km = Int((meters / 1000).rounded())
        return "\(km) km"
    }
}

/// Payload posted on `.didDetectMove` so views can present an alert with the
/// refined locality + distance.
public struct MoveDetectedPayload: Sendable {
    public let savedCityName: String
    public let detectedCoordinate: CLLocationCoordinate2D
    public let distanceMeters: CLLocationDistance
    /// CLGeocoder-resolved locality if available, else empty.
    public let detectedLocality: String

    public init(
        savedCityName: String,
        detectedCoordinate: CLLocationCoordinate2D,
        distanceMeters: CLLocationDistance,
        detectedLocality: String
    ) {
        self.savedCityName = savedCityName
        self.detectedCoordinate = detectedCoordinate
        self.distanceMeters = distanceMeters
        self.detectedLocality = detectedLocality
    }

    public var distanceKmString: String {
        AutoDetectMoveCheck.formatKilometers(distanceMeters)
    }
}
