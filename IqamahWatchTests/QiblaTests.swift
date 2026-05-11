import CoreLocation
import IqamahCore
import Testing

@Suite("Qibla Bearing Tests")
struct QiblaTests {
    @Test("Qibla from Riyadh is approximately 244°")
    func riyadhQibla() {
        let riyadh = CLLocationCoordinate2D(latitude: 24.7, longitude: 46.7)
        let bearing = qiblaBearing(from: riyadh)
        #expect(abs(bearing - 244.0) < 2.0,
                "Expected ~244° but got \(String(format: "%.1f", bearing))°")
    }

    @Test("Qibla from London is approximately 119°")
    func londonQibla() {
        let london = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
        let bearing = qiblaBearing(from: london)
        #expect(abs(bearing - 119.0) < 2.0,
                "Expected ~119° but got \(String(format: "%.1f", bearing))°")
    }
}
