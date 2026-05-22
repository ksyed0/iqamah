import IqamahCore
import XCTest
import CoreLocation

final class ENH001GPSTests: XCTestCase {
    var settings: SettingsManager!
    let suiteName = "test.ENH001GPS"

    override func setUp() {
        super.setUp()
        // Use a fresh UserDefaults suite so tests don't pollute shared state
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        settings = SettingsManager(userDefaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        settings = nil
        super.tearDown()
    }

    // MARK: - cachedGPSCoordinate

    func testCachedCoordinateIsNilWhenNeverSaved() {
        XCTAssertNil(settings.cachedGPSCoordinate())
    }

    func testCachedCoordinateRoundTrip() {
        let coord = CLLocationCoordinate2D(latitude: 43.685, longitude: -79.759)
        settings.saveGPSCoordinates(coord)
        let recalled = settings.cachedGPSCoordinate()
        XCTAssertNotNil(recalled)
        XCTAssertEqual(recalled!.latitude,  coord.latitude,  accuracy: 0.0001)
        XCTAssertEqual(recalled!.longitude, coord.longitude, accuracy: 0.0001)
    }

    func testCachedCoordinateAtNullIsland() {
        // (0, 0) is Null Island — a real geographic point, should NOT return nil
        let coord = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        settings.saveGPSCoordinates(coord)
        let recalled = settings.cachedGPSCoordinate()
        XCTAssertNotNil(recalled, "Null Island (0,0) is a real coordinate and should not be treated as empty")
    }

    // MARK: - locationSource defaults

    func testLocationSourceDefaultsToManual() {
        XCTAssertEqual(settings.locationSource, "manual")
    }

    func testLocationSourcePersists() {
        settings.locationSource = "gps"
        let reloaded = SettingsManager(userDefaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(reloaded.locationSource, "gps")
    }

    // MARK: - gpsLocality defaults

    func testGPSLocalityDefaultsToEmpty() {
        XCTAssertEqual(settings.gpsLocality, "")
    }

    func testGPSLocalityPersists() {
        settings.gpsLocality = "Brampton"
        let reloaded = SettingsManager(userDefaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(reloaded.gpsLocality, "Brampton")
    }

    // MARK: - gpsTimezone defaults

    func testGPSTimezoneDefaultsToCurrentDevice() {
        XCTAssertEqual(settings.gpsTimezone, TimeZone.current.identifier)
    }

    // MARK: - isLegacyV15User

    func testIsLegacyV15UserTrueWhenHasCompletedSetupButLocationSourceAbsent() {
        let suiteName = "test.enh001.legacyV15"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        suite.set(true, forKey: "hasCompletedSetup")
        // locationSource key intentionally NOT set
        let mgr = SettingsManager(userDefaults: suite)
        XCTAssertTrue(mgr.isLegacyV15User)
        suite.removePersistentDomain(forName: suiteName)
    }

    func testIsLegacyV15UserFalseOnFreshInstall() {
        let suiteName = "test.enh001.fresh"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        let mgr = SettingsManager(userDefaults: suite)
        XCTAssertFalse(mgr.isLegacyV15User)
        suite.removePersistentDomain(forName: suiteName)
    }

    func testIsLegacyV15UserFalseAfterLocationSourceSet() {
        let suiteName = "test.enh001.migrated"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        suite.set(true, forKey: "hasCompletedSetup")
        suite.set("manual", forKey: "locationSource")
        let mgr = SettingsManager(userDefaults: suite)
        XCTAssertFalse(mgr.isLegacyV15User)
        suite.removePersistentDomain(forName: suiteName)
    }

    // MARK: - didShowGPSReDetectPromptV16

    func testDidShowGPSReDetectPromptV16Persists() {
        let suiteName = "test.enh001.prompt"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        let mgr = SettingsManager(userDefaults: suite)
        XCTAssertFalse(mgr.didShowGPSReDetectPromptV16)
        mgr.didShowGPSReDetectPromptV16 = true
        let mgr2 = SettingsManager(userDefaults: suite)
        XCTAssertTrue(mgr2.didShowGPSReDetectPromptV16)
        suite.removePersistentDomain(forName: suiteName)
    }
}
