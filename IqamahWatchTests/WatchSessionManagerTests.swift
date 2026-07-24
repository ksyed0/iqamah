import IqamahCore
import Testing
import WatchConnectivity
@testable import IqamahWatch

@Suite("WatchSessionManager — didReceiveUserInfo")
@MainActor
struct WatchSessionManagerTests {

    @Test("updates calculationMethod when received from phone")
    func receivesCalculationMethod() async {
        let settings = SettingsManager.watchStub()
        settings.calculationMethod = .isna
        WatchSessionManager.shared.wireSettings(settings)
        WatchSessionManager.shared.session(WCSession.default, didReceiveUserInfo: [
            "calculationMethod": CalculationMethod.muslimWorldLeague.rawValue,
        ])
        await Task.yield()
        await Task.yield()
        #expect(settings.calculationMethod == .muslimWorldLeague)
    }

    @Test("updates asrMethod when received from phone")
    func receivesAsrMethod() async {
        let settings = SettingsManager.watchStub()
        settings.asrMethod = .standard
        WatchSessionManager.shared.wireSettings(settings)
        WatchSessionManager.shared.session(WCSession.default, didReceiveUserInfo: [
            "asrMethod": AsrJuristicMethod.hanafi.rawValue,
        ])
        await Task.yield()
        await Task.yield()
        #expect(settings.asrMethod == .hanafi)
    }

    @Test("updates use24HourTime when received from phone")
    func receives24HourPreference() async {
        let settings = SettingsManager.watchStub()
        settings.use24HourTime = false
        WatchSessionManager.shared.wireSettings(settings)
        WatchSessionManager.shared.session(WCSession.default, didReceiveUserInfo: [
            "use24HourTime": true,
        ])
        await Task.yield()
        await Task.yield()
        #expect(settings.use24HourTime == true)
    }

    @Test("saves city when all location fields are present")
    func receivesCity() async {
        let settings = SettingsManager.watchStub()
        WatchSessionManager.shared.wireSettings(settings)
        WatchSessionManager.shared.session(WCSession.default, didReceiveUserInfo: [
            "selectedCityName": "London",
            "selectedCityCountryCode": "GB",
            "selectedCityLatitude": 51.5074,
            "selectedCityLongitude": -0.1278,
            "selectedCityTimezone": "Europe/London",
        ])
        await Task.yield()
        await Task.yield()
        #expect(settings.loadCity()?.name == "London")
    }

    @Test("ignores partial city info — does not save without all required fields")
    func ignoresPartialCityInfo() async {
        let settings = SettingsManager.watchStub()
        let cityBefore = settings.loadCity()?.name
        WatchSessionManager.shared.wireSettings(settings)
        // Missing countryCode, lat, lon, timezone — city save is skipped
        WatchSessionManager.shared.session(WCSession.default, didReceiveUserInfo: [
            "selectedCityName": "ShouldNotSave",
        ])
        await Task.yield()
        await Task.yield()
        #expect(settings.loadCity()?.name == cityBefore)
    }
}
