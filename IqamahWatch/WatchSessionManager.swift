import IqamahCore
import WatchConnectivity
import WidgetKit

@MainActor
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    private var settingsRef: SettingsManager?
    override private init() {}

    func activate(settings: SettingsManager) {
        settingsRef = settings
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // Internal accessor used by unit tests to inject a settings instance without
    // requiring a live WCSession (which isn't available on simulator).
    func wireSettings(_ settings: SettingsManager) {
        settingsRef = settings
    }

    nonisolated func session(_: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in applyUserInfo(userInfo) }
    }

    // Extracted so unit tests can call this synchronously without Task-timing races.
    func applyUserInfo(_ userInfo: [String: Any]) {
        guard let settings = settingsRef else { return }
        if let raw = userInfo["calculationMethod"] as? String,
           let method = CalculationMethod(rawValue: raw) {
            settings.calculationMethod = method
        }
        if let raw = userInfo["asrMethod"] as? String,
           let asr = AsrJuristicMethod(rawValue: raw) {
            settings.asrMethod = asr
        }
        if let use24 = userInfo["use24HourTime"] as? Bool {
            settings.use24HourTime = use24
        }
        if let name = userInfo["selectedCityName"] as? String,
           let code = userInfo["selectedCityCountryCode"] as? String,
           let lat = userInfo["selectedCityLatitude"] as? Double,
           let lon = userInfo["selectedCityLongitude"] as? Double,
           let tz = userInfo["selectedCityTimezone"] as? String,
           let city = try? City(name: name, countryCode: code,
                                latitude: lat, longitude: lon, timezone: tz) {
            settings.saveCity(city)
            settings.locationSource = "manual"
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    nonisolated func session(_: WCSession,
                             activationDidCompleteWith _: WCSessionActivationState,
                             error _: Error?) {}
}
