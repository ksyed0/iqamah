import Foundation
import IqamahCore
import Testing

@Suite("Astronomy Engine Tests")
struct AstronomyTests {

    // Reference: Meeus Example 47.a — Moon position on 1992-Apr-12 00:00 TT
    // Expected: longitude ≈ 133.167°, latitude ≈ -3.229°, distance ≈ 368409 km
    @Test("Moon longitude for Meeus Example 47.a (1992-Apr-12) within ±0.5°")
    func moonLongitudeMeeus47a() {
        let jd = 2_448_724.5 // 1992 April 12, 0h TT
        let pos = MoonPosition.compute(julianDay: jd)
        #expect(abs(pos.longitude - 133.167) < 0.5)
    }

    @Test("Moon latitude for Meeus Example 47.a within ±0.5°")
    func moonLatitudeMeeus47a() {
        let jd = 2_448_724.5
        let pos = MoonPosition.compute(julianDay: jd)
        #expect(abs(pos.latitude - (-3.229)) < 0.5)
    }

    @Test("Moon distance for Meeus Example 47.a within ±5000 km")
    func moonDistanceMeeus47a() {
        let jd = 2_448_724.5
        let pos = MoonPosition.compute(julianDay: jd)
        #expect(abs(pos.distanceKm - 368409.0) < 5000.0)
    }

    // Sun reference: Meeus Example 25.a — 1992-Oct-13
    // Expected: longitude ≈ 199.909°, RA ≈ 198.378°, Dec ≈ -7.785°
    @Test("Sun longitude for Meeus Example 25.a (1992-Oct-13) within ±0.1°")
    func sunLongitudeMeeus25a() {
        let jd = 2_448_908.5 // 1992 Oct 13, 0h TT
        let pos = SunPosition.compute(julianDay: jd)
        #expect(abs(pos.longitude - 199.909) < 0.1)
    }

    @Test("Sun declination for Meeus Example 25.a within ±0.1°")
    func sunDeclinationMeeus25a() {
        let jd = 2_448_908.5
        let pos = SunPosition.compute(julianDay: jd)
        #expect(abs(pos.declination - (-7.785)) < 0.1)
    }

    // New moon reference: 2024-Jan-11 new moon = JD ≈ 2460320.65
    @Test("NewMoon.julianDayOfNewMoon gives Jan 2024 new moon within 0.5 days")
    func newMoonJan2024() {
        let T = (2_460_320.65 - 2_451_545.0) / 36525.0
        let k = (T * 1236.85).rounded()
        let jd = NewMoon.julianDayOfNewMoon(k: k)
        #expect(abs(jd - 2_460_320.65) < 0.5)
    }

    @Test("Angular separation between identical points is 0")
    func angularSeparationZero() {
        let sep = angularSeparation(ra1: 45.0, dec1: 30.0, ra2: 45.0, dec2: 30.0)
        #expect(sep < 0.0001)
    }

    @Test("Angular separation between 180° apart points is 180°")
    func angularSeparation180() {
        let sep = angularSeparation(ra1: 0.0, dec1: 0.0, ra2: 180.0, dec2: 0.0)
        #expect(abs(sep - 180.0) < 0.001)
    }

    @Test("Crescent width is positive for typical elongation")
    func crescentWidthPositive() {
        let w = crescentWidthArcmin(arclDegrees: 10.0, moonDistanceKm: 385000)
        #expect(w > 0)
        #expect(w < 5) // typical for 10° elongation
    }

    @Test("JulianDay round-trip preserves date within 1 second")
    func julianDayRoundTrip() {
        let now = Date()
        let jd = now.julianDay
        let recovered = Date.fromJulianDay(jd)
        #expect(abs(now.timeIntervalSince(recovered)) < 1.0)
    }
}
