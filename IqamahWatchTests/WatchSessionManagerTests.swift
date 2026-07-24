import IqamahCore
import Testing
import WatchConnectivity
@testable import IqamahWatch

@Suite("WatchSessionManager — applyUserInfo")
@MainActor
struct WatchSessionManagerTests {

    // Call applyUserInfo directly — avoids Task-timing races that arise when
    // testing through the nonisolated session(_:didReceiveUserInfo:) delegate.

    @Test("updates calculationMethod when received from phone")
    func receivesCalculationMethod() {
        let settings = SettingsManager.watchStub()
        settings.calculationMethod = .isna
        WatchSessionManager.shared.wireSettings(settings)
        WatchSessionManager.shared.applyUserInfo([
            "calculationMethod": CalculationMethod.muslimWorldLeague.rawValue,
        ])
        #expect(settings.calculationMethod == .muslimWorldLeague)
    }

    @Test("updates asrMethod when received from phone")
    func receivesAsrMethod() {
        let settings = SettingsManager.watchStub()
        settings.asrMethod = .standard
        WatchSessionManager.shared.wireSettings(settings)
        WatchSessionManager.shared.applyUserInfo([
            "asrMethod": AsrJuristicMethod.hanafi.rawValue,
        ])
        #expect(settings.asrMethod == .hanafi)
    }

    @Test("updates use24HourTime when received from phone")
    func receives24HourPreference() {
        let settings = SettingsManager.watchStub()
        settings.use24HourTime = false
        WatchSessionManager.shared.wireSettings(settings)
        WatchSessionManager.shared.applyUserInfo(["use24HourTime": true])
        #expect(settings.use24HourTime == true)
    }

    @Test("saves city when all location fields are present")
    func receivesCity() {
        let settings = SettingsManager.watchStub()
        WatchSessionManager.shared.wireSettings(settings)
        WatchSessionManager.shared.applyUserInfo([
            "selectedCityName": "London",
            "selectedCityCountryCode": "GB",
            "selectedCityLatitude": 51.5074,
            "selectedCityLongitude": -0.1278,
            "selectedCityTimezone": "Europe/London",
        ])
        #expect(settings.loadCity()?.name == "London")
    }

    @Test("ignores partial city info — does not save without all required fields")
    func ignoresPartialCityInfo() {
        let settings = SettingsManager.watchStub()
        let cityBefore = settings.loadCity()?.name
        WatchSessionManager.shared.wireSettings(settings)
        // Missing countryCode, lat, lon, timezone — city save is skipped
        WatchSessionManager.shared.applyUserInfo(["selectedCityName": "ShouldNotSave"])
        #expect(settings.loadCity()?.name == cityBefore)
    }
}
