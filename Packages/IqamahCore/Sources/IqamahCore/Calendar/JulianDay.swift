import Foundation

/// Julian Day Number helpers — the continuous day count used in astronomical calculations.
public extension Date {
    /// Returns the Julian Day Number for this date.
    var julianDay: Double {
        // J2000.0 epoch = JD 2451545.0 = 2000-Jan-01 12:00 TT
        // timeIntervalSinceReferenceDate uses 2001-Jan-01 00:00 UTC
        // J2000.0 relative to referenceDate: 365.25 days back = -946728000 + 43200 = ... compute directly
        let secondsPerDay = 86400.0
        // Reference date (2001-01-01 00:00 UTC) in Julian Days:
        // JD(2001-01-01 00:00 UTC) = 2451910.5
        let referenceJD = 2_451_910.5
        return referenceJD + timeIntervalSinceReferenceDate / secondsPerDay
    }

    /// Creates a Date from a Julian Day Number.
    static func fromJulianDay(_ jd: Double) -> Date {
        let referenceJD = 2_451_910.5
        let secondsPerDay = 86400.0
        return Date(timeIntervalSinceReferenceDate: (jd - referenceJD) * secondsPerDay)
    }
}
