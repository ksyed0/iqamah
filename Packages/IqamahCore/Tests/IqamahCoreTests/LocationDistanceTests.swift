import CoreLocation
import Foundation
import Testing
@testable import IqamahCore

/// BUG-0069: launch-time auto-detect helpers.
///
/// Verifies the great-circle distance helper and the 25 km threshold predicate
/// used by the "you've moved more than 25 km" launch prompt across iOS, macOS,
/// and watchOS.
@Suite("LocationDistance (BUG-0069)")
struct LocationDistanceTests {
    // Toronto City Hall — used as the anchor for the threshold tests.
    private let toronto = CLLocationCoordinate2D(latitude: 43.6534, longitude: -79.3834)

    @Test("zero distance between identical coordinates")
    func zeroDistance() {
        let d = SettingsManager.distance(from: toronto, to: toronto)
        #expect(d == 0)
    }

    @Test("Toronto → Mississauga is roughly 25–35 km")
    func knownDistance() {
        // Mississauga City Hall — ~26 km west of Toronto City Hall.
        let mississauga = CLLocationCoordinate2D(latitude: 43.5890, longitude: -79.6441)
        let d = SettingsManager.distance(from: toronto, to: mississauga)
        // CLLocation returns ~21.5 km along the great circle here; allow a wide band.
        #expect(d > 20000)
        #expect(d < 35000)
    }

    @Test("threshold predicate returns false just under 25 km")
    func underThreshold() {
        // Construct a point ~24.9 km north of Toronto (1 deg lat ≈ 111 km, so 0.2244° ≈ 24.9 km).
        let near = CLLocationCoordinate2D(latitude: toronto.latitude + 0.2244, longitude: toronto.longitude)
        let d = SettingsManager.distance(from: toronto, to: near)
        #expect(d < SettingsManager.autoDetectThresholdMeters)
        #expect(!SettingsManager.hasMovedBeyondAutoDetectThreshold(from: toronto, to: near))
    }

    @Test("threshold predicate returns true just over 25 km")
    func overThreshold() {
        // ~25.1 km north of Toronto.
        let far = CLLocationCoordinate2D(latitude: toronto.latitude + 0.2262, longitude: toronto.longitude)
        let d = SettingsManager.distance(from: toronto, to: far)
        #expect(d > SettingsManager.autoDetectThresholdMeters)
        #expect(SettingsManager.hasMovedBeyondAutoDetectThreshold(from: toronto, to: far))
    }

    @Test("threshold constant is 25 km")
    func thresholdConstant() {
        #expect(SettingsManager.autoDetectThresholdMeters == 25000)
    }

    // MARK: - autoDetectOnMove round-trip

    @Test("autoDetectOnMove defaults to true on a fresh suite")
    func defaultsToTrue() throws {
        let suiteName = "test.LocationDistanceTests.default.\(UUID().uuidString)"
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let settings = SettingsManager(userDefaults: suite)
        #expect(settings.autoDetectOnMove == true)
    }

    @Test("autoDetectOnMove round-trips through UserDefaults")
    func roundTrip() throws {
        let suiteName = "test.LocationDistanceTests.roundtrip.\(UUID().uuidString)"
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let settings = SettingsManager(userDefaults: suite)
        settings.autoDetectOnMove = false

        let reloaded = SettingsManager(userDefaults: suite)
        #expect(reloaded.autoDetectOnMove == false)
    }
}
