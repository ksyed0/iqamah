import Foundation

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults: UserDefaults

    private enum Keys {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let selectedCityName = "selectedCityName"
        static let selectedCityCountryCode = "selectedCityCountryCode"
        static let selectedCityLatitude = "selectedCityLatitude"
        static let selectedCityLongitude = "selectedCityLongitude"
        static let selectedCityTimezone = "selectedCityTimezone"
        static let calculationMethod = "calculationMethod"
        static let asrMethod = "asrMethod"
        static let prayerAdjustments = "prayerAdjustments"
        static let use24HourTime = "use24HourTime"
        static let prayerAdhaanIds = "prayerAdhaanIds"
        static let mutedPrayers = "mutedPrayers"
    }

    @Published var hasCompletedSetup: Bool {
        didSet {
            defaults.set(hasCompletedSetup, forKey: Keys.hasCompletedSetup)
        }
    }

    @Published var calculationMethod: CalculationMethod {
        didSet {
            defaults.set(calculationMethod.rawValue, forKey: Keys.calculationMethod)
        }
    }

    @Published var asrMethod: AsrJuristicMethod {
        didSet {
            defaults.set(asrMethod.rawValue, forKey: Keys.asrMethod)
        }
    }

    @Published var use24HourTime: Bool {
        didSet {
            defaults.set(use24HourTime, forKey: Keys.use24HourTime)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        hasCompletedSetup = userDefaults.bool(forKey: Keys.hasCompletedSetup)

        if let methodRaw = defaults.string(forKey: Keys.calculationMethod),
           let method = CalculationMethod(rawValue: methodRaw) {
            calculationMethod = method
        } else {
            calculationMethod = .muslimWorldLeague
        }

        if let asrRaw = defaults.string(forKey: Keys.asrMethod),
           let asr = AsrJuristicMethod(rawValue: asrRaw) {
            asrMethod = asr
        } else {
            asrMethod = .standard
        }

        use24HourTime = defaults.bool(forKey: Keys.use24HourTime)
    }

    func saveCity(_ city: City) {
        defaults.set(city.name, forKey: Keys.selectedCityName)
        defaults.set(city.countryCode, forKey: Keys.selectedCityCountryCode)
        defaults.set(city.latitude, forKey: Keys.selectedCityLatitude)
        defaults.set(city.longitude, forKey: Keys.selectedCityLongitude)
        defaults.set(city.timezone, forKey: Keys.selectedCityTimezone)
    }

    func loadCity() -> City? {
        guard let name = defaults.string(forKey: Keys.selectedCityName),
              let countryCode = defaults.string(forKey: Keys.selectedCityCountryCode),
              let timezone = defaults.string(forKey: Keys.selectedCityTimezone)
        else {
            return nil
        }

        let latitude = defaults.double(forKey: Keys.selectedCityLatitude)
        let longitude = defaults.double(forKey: Keys.selectedCityLongitude)

        // Validate that we have actual coordinates
        if latitude == 0, longitude == 0 {
            return nil
        }

        return try? City(
            name: name,
            countryCode: countryCode,
            latitude: latitude,
            longitude: longitude,
            timezone: timezone
        )
    }

    func completeSetup(city: City, calculationMethod: CalculationMethod, asrMethod: AsrJuristicMethod) {
        saveCity(city)
        self.calculationMethod = calculationMethod
        self.asrMethod = asrMethod
        hasCompletedSetup = true

        // Notify that settings changed so menu bar can update
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    func resetSettings() {
        hasCompletedSetup = false
        calculationMethod = .muslimWorldLeague
        asrMethod = .standard
        use24HourTime = false
        for key in [Keys.selectedCityName, Keys.selectedCityCountryCode,
                    Keys.selectedCityLatitude, Keys.selectedCityLongitude,
                    Keys.selectedCityTimezone, Keys.calculationMethod,
                    Keys.asrMethod, Keys.prayerAdjustments, Keys.use24HourTime] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Prayer Time Adjustments

    func getAdjustment(for prayerName: String) -> Int {
        let adjustments = defaults.dictionary(forKey: Keys.prayerAdjustments) as? [String: Int] ?? [:]
        return adjustments[prayerName] ?? 0
    }

    // MARK: - Adhaan Selection

    func getAdhaan(for prayerName: String) -> Adhaan {
        let map = defaults.dictionary(forKey: Keys.prayerAdhaanIds) as? [String: String] ?? [:]
        let id = map[prayerName] ?? "silent"
        return Adhaan.available.first { $0.id == id } ?? .silent
    }

    func setAdhaan(_ adhaan: Adhaan, for prayerName: String) {
        var map = defaults.dictionary(forKey: Keys.prayerAdhaanIds) as? [String: String] ?? [:]
        map[prayerName] = adhaan.id
        defaults.set(map, forKey: Keys.prayerAdhaanIds)
    }

    // MARK: - Per-Prayer Mute

    func isPrayerMuted(_ prayerName: String) -> Bool {
        let arr = defaults.stringArray(forKey: Keys.mutedPrayers) ?? []
        return arr.contains(prayerName)
    }

    func setPrayerMuted(_ muted: Bool, for prayerName: String) {
        var set = Set(defaults.stringArray(forKey: Keys.mutedPrayers) ?? [])
        if muted { set.insert(prayerName) } else { set.remove(prayerName) }
        defaults.set(Array(set), forKey: Keys.mutedPrayers)
    }

    func setAdjustment(_ minutes: Int, for prayerName: String) {
        var adjustments = defaults.dictionary(forKey: Keys.prayerAdjustments) as? [String: Int] ?? [:]
        adjustments[prayerName] = minutes
        defaults.set(adjustments, forKey: Keys.prayerAdjustments)

        // Notify that settings changed
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}
