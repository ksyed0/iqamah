import Foundation

/// New moon search using Meeus Chapter 49.
public struct NewMoon {
    /// Returns the Julian Day of the new moon closest to (but not after) the start date,
    /// searching up to `daysAhead` days forward if needed.
    public static func search(startDate: Date, daysAhead: Double = 35) -> Date? {
        let jdStart = startDate.julianDay
        let jdEnd = jdStart + daysAhead

        // Approximate k for start date (k = integer cycles from J2000.0 new moon)
        let T0 = (jdStart - 2_451_545.0) / 36525.0
        let k0 = (T0 * 1236.85).rounded(.down)

        for dk in 0 ... 3 {
            let jd = julianDayOfNewMoon(k: k0 + Double(dk))
            if jd >= jdStart, jd <= jdEnd {
                return Date.fromJulianDay(jd)
            }
        }
        return nil
    }

    /// Previous new moon before or on the given date.
    public static func previous(before date: Date) -> Date {
        let jd = date.julianDay
        let T0 = (jd - 2_451_545.0) / 36525.0
        var k = (T0 * 1236.85).rounded(.down)
        var candidate = julianDayOfNewMoon(k: k)
        // Walk back if candidate is after jd
        while candidate > jd {
            k -= 1
            candidate = julianDayOfNewMoon(k: k)
        }
        return Date.fromJulianDay(candidate)
    }

    /// Julian Day of new moon for cycle k (Meeus eq. 49.1–49.5).
    public static func julianDayOfNewMoon(k: Double) -> Double {
        let T = k / 1236.85
        var JDE = 2_451_550.09766 + 29.530588861 * k
            + 0.00015437 * T * T - 0.000000150 * T * T * T
            + 0.00000000073 * T * T * T * T

        let M = 2.5534 + 29.10535670 * k - 0.0000014 * T * T - 0.00000011 * T * T * T
        let Mp = 201.5643 + 385.81693528 * k + 0.0107582 * T * T + 0.00001238 * T * T * T - 0.000000058 * T * T * T * T
        let F = 160.7108 + 390.67050284 * k - 0.0016118 * T * T - 0.00000227 * T * T * T + 0.000000011 * T * T * T * T
        let Om = 124.7746 - 1.56375588 * k + 0.0020672 * T * T + 0.00000215 * T * T * T

        let E = 1 - 0.002516 * T - 0.0000074 * T * T
        let d2r = Double.pi / 180.0

        // Planetary corrections (Table 49-A)
        JDE += -0.40720 * sin(Mp * d2r)
            + 0.17241 * E * sin(M * d2r)
            + 0.01608 * sin(2 * Mp * d2r)
            + 0.01039 * sin(2 * F * d2r)
            + 0.00739 * E * sin((Mp - M) * d2r)
            - 0.00514 * E * sin((Mp + M) * d2r)
            + 0.00208 * E * E * sin(2 * M * d2r)
            - 0.00111 * sin((Mp - 2 * F) * d2r)
            - 0.00057 * sin((Mp + 2 * F) * d2r)
            + 0.00056 * E * sin((2 * Mp + M) * d2r)
            - 0.00042 * sin(3 * Mp * d2r)
            + 0.00042 * E * sin((M + 2 * F) * d2r)
            + 0.00038 * E * sin((M - 2 * F) * d2r)
            - 0.00024 * E * sin((2 * Mp - M) * d2r)
            - 0.00017 * sin(Om * d2r)
            - 0.00007 * sin((Mp + 2 * M) * d2r)
            + 0.00004 * sin((2 * Mp - 2 * F) * d2r)
            + 0.00004 * sin(3 * M * d2r)
            + 0.00003 * sin((Mp + M - 2 * F) * d2r)
            + 0.00003 * sin((2 * Mp + 2 * F) * d2r)
            - 0.00003 * sin((Mp + M + 2 * F) * d2r)
            + 0.00003 * sin((Mp - M + 2 * F) * d2r)
            - 0.00002 * sin((Mp - M - 2 * F) * d2r)
            - 0.00002 * sin((3 * Mp + M) * d2r)
            + 0.00002 * sin(4 * Mp * d2r)

        return JDE
    }
}
