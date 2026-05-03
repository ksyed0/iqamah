import Testing
import Foundation
import CoreLocation

@Suite("Prayer Time Accuracy Regression Tests")
struct PrayerAccuracyRegressionTests {
    private static func referenceDate(in tz: TimeZone) -> Date {
        var c = DateComponents()
        c.timeZone = tz
        c.year = 2024
        c.month = 1
        c.day = 15
        c.hour = 12
        c.minute = 0
        c.second = 0
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func hm(_ date: Date, in tz: TimeZone) -> (Int, Int) {
        let comps = Calendar(identifier: .gregorian)
            .dateComponents(in: tz, from: date)
        return (comps.hour!, comps.minute!)
    }

    private func assertWithin3Min(
        _ actual: Date,
        expected: (h: Int, m: Int),
        in tz: TimeZone,
        label: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let (ah, am) = hm(actual, in: tz)
        let actualMin = ah * 60 + am
        let expectedMin = expected.h * 60 + expected.m
        let diff = abs(actualMin - expectedMin)
        let msg: Comment = "\(label): expected \(expected.h):\(String(format: "%02d", expected.m)), got \(ah):\(String(format: "%02d", am)) (diff \(diff) min)"
        #expect(diff <= 3, msg, sourceLocation: sourceLocation)
    }

    // MARK: - Makkah

    @Test("Makkah (MWL, 2024-01-15) prayer times within ±3 min of reference")
    func makkahAccuracy() throws {
        let tz = try #require(TimeZone(identifier: "Asia/Riyadh"))
        let calculator = PrayerCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262),
            timezone: tz,
            method: .muslimWorldLeague,
            asrMethod: .standard
        )
        let times = try calculator.calculate(for: Self.referenceDate(in: tz))

        assertWithin3Min(times.fajr, expected: (5, 42), in: tz, label: "Makkah Fajr")
        assertWithin3Min(times.dhuhr, expected: (12, 30), in: tz, label: "Makkah Dhuhr")
        assertWithin3Min(times.asr, expected: (15, 36), in: tz, label: "Makkah Asr")
        assertWithin3Min(times.maghrib, expected: (17, 58), in: tz, label: "Makkah Maghrib")
        assertWithin3Min(times.isha, expected: (19, 12), in: tz, label: "Makkah Isha")
    }

    // MARK: - New York

    @Test("New York (MWL, 2024-01-15) prayer times within ±3 min of reference")
    func newYorkAccuracy() throws {
        let tz = try #require(TimeZone(identifier: "America/New_York"))
        let calculator = PrayerCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.006),
            timezone: tz,
            method: .muslimWorldLeague,
            asrMethod: .standard
        )
        let times = try calculator.calculate(for: Self.referenceDate(in: tz))

        assertWithin3Min(times.fajr, expected: (5, 41), in: tz, label: "New York Fajr")
        assertWithin3Min(times.dhuhr, expected: (12, 6), in: tz, label: "New York Dhuhr")
        assertWithin3Min(times.asr, expected: (14, 32), in: tz, label: "New York Asr")
        assertWithin3Min(times.maghrib, expected: (16, 51), in: tz, label: "New York Maghrib")
        assertWithin3Min(times.isha, expected: (18, 23), in: tz, label: "New York Isha")
    }

    // MARK: - London

    @Test("London (MWL, 2024-01-15) prayer times within ±3 min of reference")
    func londonAccuracy() throws {
        let tz = try #require(TimeZone(identifier: "Europe/London"))
        let calculator = PrayerCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            timezone: tz,
            method: .muslimWorldLeague,
            asrMethod: .standard
        )
        let times = try calculator.calculate(for: Self.referenceDate(in: tz))

        assertWithin3Min(times.fajr, expected: (5, 59), in: tz, label: "London Fajr")
        assertWithin3Min(times.dhuhr, expected: (12, 10), in: tz, label: "London Dhuhr")
        assertWithin3Min(times.asr, expected: (13, 59), in: tz, label: "London Asr")
        assertWithin3Min(times.maghrib, expected: (16, 18), in: tz, label: "London Maghrib")
        assertWithin3Min(times.isha, expected: (18, 12), in: tz, label: "London Isha")
    }

    // MARK: - Jakarta

    @Test("Jakarta (MWL, 2024-01-15) prayer times within ±3 min of reference")
    func jakartaAccuracy() throws {
        let tz = try #require(TimeZone(identifier: "Asia/Jakarta"))
        let calculator = PrayerCalculator(
            coordinate: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
            timezone: tz,
            method: .muslimWorldLeague,
            asrMethod: .standard
        )
        let times = try calculator.calculate(for: Self.referenceDate(in: tz))

        assertWithin3Min(times.fajr, expected: (4, 33), in: tz, label: "Jakarta Fajr")
        assertWithin3Min(times.dhuhr, expected: (12, 2), in: tz, label: "Jakarta Dhuhr")
        assertWithin3Min(times.asr, expected: (15, 26), in: tz, label: "Jakarta Asr")
        assertWithin3Min(times.maghrib, expected: (18, 14), in: tz, label: "Jakarta Maghrib")
        assertWithin3Min(times.isha, expected: (19, 25), in: tz, label: "Jakarta Isha")
    }

    // MARK: - Toronto

    @Test("Toronto (MWL, 2024-01-15) prayer times within ±3 min of reference")
    func torontoAccuracy() throws {
        let tz = try #require(TimeZone(identifier: "America/Toronto"))
        let calculator = PrayerCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
            timezone: tz,
            method: .muslimWorldLeague,
            asrMethod: .standard
        )
        let times = try calculator.calculate(for: Self.referenceDate(in: tz))

        assertWithin3Min(times.fajr, expected: (6, 6), in: tz, label: "Toronto Fajr")
        assertWithin3Min(times.dhuhr, expected: (12, 27), in: tz, label: "Toronto Dhuhr")
        assertWithin3Min(times.asr, expected: (14, 45), in: tz, label: "Toronto Asr")
        assertWithin3Min(times.maghrib, expected: (17, 5), in: tz, label: "Toronto Maghrib")
        assertWithin3Min(times.isha, expected: (18, 43), in: tz, label: "Toronto Isha")
    }
}
