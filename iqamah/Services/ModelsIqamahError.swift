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
        case .invalidCoordinates(let lat, let lon):
            return "Invalid coordinates: latitude \(lat)° (must be -90 to 90), longitude \(lon)° (must be -180 to 180)"
        case .invalidDate(let message):
            return "Invalid date: \(message)"
        case .invalidCalculationMethod(let method):
            return "Calculation method '\(method)' is not recognized"
        case .invalidTimezone(let timezone):
            return "Timezone '\(timezone)' is not valid"
        case .invalidAdjustment(let minutes, let range):
            return "Prayer time adjustment of \(minutes) minutes is outside allowed range (\(range.lowerBound) to \(range.upperBound))"
            
        // IntegrationError
        case .locationServicesDenied:
            return "Location access denied. Please enable location services in System Settings > Privacy & Security > Location Services."
        case .locationServicesFailed(let error):
            return "Failed to get location: \(error.localizedDescription)"
        case .locationServicesRestricted:
            return "Location services are restricted on this device. Please check parental controls or device management settings."
        case .settingsPersistenceFailed(let error):
            return "Failed to save settings: \(error.localizedDescription)"
        case .citiesDatabaseLoadFailed(let reason):
            return "Unable to load cities database: \(reason)"
        case .citiesDatabaseNotFound:
            return "Cities database not found. Please reinstall the app or contact support."
        case .citiesDatabaseCorrupted(let error):
            return "Cities database is corrupted: \(error.localizedDescription). Please reinstall the app."
            
        // BusinessLogicError
        case .invalidPrayerTime(let prayer, let reason):
            return "Invalid time calculated for \(prayer): \(reason)"
        case .invalidQiblahAngle(let angle):
            return "Invalid Qibla angle: \(angle)° (must be 0-360)"
        case .prayerTimeCalculationFailed(let reason):
            return "Prayer time calculation failed: \(reason)"
        case .hijriConversionFailed(let date):
            return "Failed to convert \(date) to Hijri calendar"
            
        // SystemError
        case .unexpectedError(let message):
            return "An unexpected error occurred: \(message)"
        case .serviceInitializationFailed(let service):
            return "Failed to initialize \(service). Please restart the app."
        case .resourceNotFound(let resource):
            return "Required resource '\(resource)' not found"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .locationServicesDenied, .locationServicesRestricted:
            return "Location permission is required to calculate accurate prayer times for your current location."
        case .citiesDatabaseNotFound, .citiesDatabaseCorrupted:
            return "The app's cities database is missing or damaged."
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .locationServicesDenied:
            return "Open System Settings, go to Privacy & Security > Location Services, and enable location access for Iqamah."
        case .locationServicesRestricted:
            return "Contact your device administrator to enable location services."
        case .citiesDatabaseNotFound, .citiesDatabaseCorrupted:
            return "Try reinstalling the app. If the problem persists, contact support."
        case .invalidCoordinates:
            return "Please select a valid city from the list or check your GPS location."
        default:
            return nil
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
            return true
        default:
            return false
        }
    }
    
    /// Returns the logging level this error should use
    var logLevel: String {
        switch self {
        case .invalidCoordinates, .invalidDate, .invalidCalculationMethod,
             .invalidTimezone, .invalidAdjustment:
            return "WARN"
            
        case .locationServicesDenied, .locationServicesRestricted,
             .locationServicesFailed, .settingsPersistenceFailed,
             .citiesDatabaseLoadFailed, .citiesDatabaseNotFound,
             .citiesDatabaseCorrupted:
            return "ERROR"
            
        case .invalidPrayerTime, .invalidQiblahAngle,
             .prayerTimeCalculationFailed, .hijriConversionFailed:
            return "ERROR"
            
        case .unexpectedError, .serviceInitializationFailed, .resourceNotFound:
            return "CRITICAL"
        }
    }
}
