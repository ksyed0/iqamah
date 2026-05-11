import CoreLocation
import IqamahCore
import Testing

@Suite("QiblaCalculator Tests")
struct QiblaCalculatorTests {
    @Test("Qibla bearing from Riyadh is ~244°")
    func riyadhBearing() {
        let riyadh = CLLocationCoordinate2D(latitude: 24.7, longitude: 46.7)
        let bearing = qiblaBearing(from: riyadh)
        #expect(abs(bearing - 244.0) < 2.0, "Expected ~244°, got \(bearing)")
    }

    @Test("Qibla bearing from London is ~119°")
    func londonBearing() {
        let london = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
        let bearing = qiblaBearing(from: london)
        #expect(abs(bearing - 119.0) < 2.0, "Expected ~119°, got \(bearing)")
    }

    @Test("Distance from London to Makkah is approximately 5000 km")
    func londonDistance() {
        let london = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
        let distance = distanceToMakkahKm(from: london)
        #expect(abs(distance - 5000.0) < 250.0, "Expected ~5000 km, got \(distance)")
    }

    @Test("Bearing from Makkah to itself does not crash and returns valid angle")
    func makkahToItselfNoCrash() {
        let makkah = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        let bearing = qiblaBearing(from: makkah)
        #expect(bearing >= 0 && bearing < 360)
    }
}
