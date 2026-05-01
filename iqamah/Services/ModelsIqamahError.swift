import Foundation
import CoreLocation

/// Application-wide error types following the error taxonomy defined in architecture/ERROR_TAXONOMY.md
enum IqamahError: Error {
    // MARK: - ValidationError

    /// Bad input from user or external system
    case invalidCoordinates(latitude: Double, longitude: Double)
    case invalidDate(String)
    case invalidCalculationMethod(String)
    case invalidTimezone(String)
    case invalidAdjustment(minutes: Int, allowedRange: ClosedRange<Int>)

    // MARK: - IntegrationError

    /// External service or system failure
    case locationServicesDenied
    case locationServicesFailed(underlyingError: Error)
    case locationServicesRestricted
    case settingsPersistenceFailed(underlyingError: Error)
    case citiesDatabaseLoadFailed(reason: String)
    case citiesDatabaseNotFound
    case citiesDatabaseCorrupted(underlyingError: Error)

    // MARK: - BusinessLogicError

    /// Domain rule or constraint violation
    case invalidPrayerTime(prayer: String, reason: String)
    case invalidQiblahAngle(angle: Double)
    case prayerTimeCalculationFailed(reason: String)
    case hijriConversionFailed(date: Date)

    // MARK: - SystemError

    /// Unexpected internal failure
    case unexpectedError(message: String)
    case serviceInitializationFailed(service: String)
    case resourceNotFound(resource: String)
}

// MARK: - LocalizedError Conformance

extension IqamahError: LocalizedError {
    var errorDescription: String? {
        switch self {
        // ValidationError
        case let .invalidCoordinates(lat, lon):
            "Invalid coordinates: latitude \(lat)° (must be -90 to 90), longitude \(lon)° (must be -180 to 180)"
        case let .invalidDate(message):
            "Invalid date: \(message)"
        case let .invalidCalculationMethod(method):
            "Calculation method '\(method)' is not recognized"
        case let .invalidTimezone(timezone):
            "Timezone '\(timezone)' is not valid"
        case let .invalidAdjustment(minutes, range):
            "Prayer time adjustment of \(minutes) minutes is outside allowed range (\(range.lowerBound) to \(range.upperBound))"
        // IntegrationError
        case .locationServicesDenied:
            "Location access denied. Please enable location services in System Settings > Privacy & Security > Location Services."
        case let .locationServicesFailed(error):
            "Failed to get location: \(error.localizedDescription)"
        case .locationServicesRestricted:
            "Location services are restricted on this device. Please check parental controls or device management settings."
        case let .settingsPersistenceFailed(error):
            "Failed to save settings: \(error.localizedDescription)"
        case let .citiesDatabaseLoadFailed(reason):
            "Unable to load cities database: \(reason)"
        case .citiesDatabaseNotFound:
            "Cities database not found. Please reinstall the app or contact support."
        case let .citiesDatabaseCorrupted(error):
            "Cities database is corrupted: \(error.localizedDescription). Please reinstall the app."
        // BusinessLogicError
        case let .invalidPrayerTime(prayer, reason):
            "Invalid time calculated for \(prayer): \(reason)"
        case let .invalidQiblahAngle(angle):
            "Invalid Qibla angle: \(angle)° (must be 0-360)"
        case let .prayerTimeCalculationFailed(reason):
            "Prayer time calculation failed: \(reason)"
        case let .hijriConversionFailed(date):
            "Failed to convert \(date) to Hijri calendar"
        // SystemError
        case let .unexpectedError(message):
            "An unexpected error occurred: \(message)"
        case let .serviceInitializationFailed(service):
            "Failed to initialize \(service). Please restart the app."
        case let .resourceNotFound(resource):
            "Required resource '\(resource)' not found"
        }
    }

    var failureReason: String? {
        switch self {
        case .locationServicesDenied, .locationServicesRestricted:
            "Location permission is required to calculate accurate prayer times for your current location."
        case .citiesDatabaseNotFound, .citiesDatabaseCorrupted:
            "The app's cities database is missing or damaged."
        default:
            nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .locationServicesDenied:
            "Open System Settings, go to Privacy & Security > Location Services, and enable location access for Iqamah."
        case .locationServicesRestricted:
            "Contact your device administrator to enable location services."
        case .citiesDatabaseNotFound, .citiesDatabaseCorrupted:
            "Try reinstalling the app. If the problem persists, contact support."
        case .invalidCoordinates:
            "Please select a valid city from the list or check your GPS location."
        default:
            nil
        }
    }
}

// MARK: - Error Category Helpers

extension IqamahError {
    /// Returns true if this is a user-recoverable error
    var isRecoverable: Bool {
        switch self {
        case .locationServicesDenied, .locationServicesRestricted,
             .citiesDatabaseNotFound, .invalidCoordinates:
            true
        default:
            false
        }
    }

    /// Returns the logging level this error should use
    var logLevel: String {
        switch self {
        case .invalidCoordinates, .invalidDate, .invalidCalculationMethod,
             .invalidTimezone, .invalidAdjustment:
            "WARN"

        case .locationServicesDenied, .locationServicesRestricted,
             .locationServicesFailed, .settingsPersistenceFailed,
             .citiesDatabaseLoadFailed, .citiesDatabaseNotFound,
             .citiesDatabaseCorrupted:
            "ERROR"

        case .invalidPrayerTime, .invalidQiblahAngle,
             .prayerTimeCalculationFailed, .hijriConversionFailed:
            "ERROR"

        case .unexpectedError, .serviceInitializationFailed, .resourceNotFound:
            "CRITICAL"
        }
    }
}
