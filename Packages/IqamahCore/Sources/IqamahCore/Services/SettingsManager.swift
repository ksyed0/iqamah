import CoreLocation
import Foundation
import SwiftUI

public extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let openSettings = Notification.Name("openSettings")
    static let openHilalWatch = Notification.Name("openHilalWatch")
}

public enum AppAppearance: String, CaseIterable {
    case system, light, dark

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

public class SettingsManager: ObservableObject {
    private static let appGroupID = "group.com.fablesoft.iqamah"

    public static let shared: SettingsManager = {
        let suite = UserDefaults(suiteName: appGroupID) ?? .standard
        return SettingsManager(userDefaults: suite)
    }()

    private let defaults: UserDefaults
    private let kvs = NSUbiquitousKeyValueStore.default

    /// Guards against feedback loops when applying a remote KVS change.
    /// When true, `didSet` observers skip the KVS write-back.
    private var isApplyingRemote = false

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
        static let uiScale = "uiScale"
        static let appearance = "appAppearance"
        static let locationSource = "locationSource" // "gps" or "manual"
        static let gpsLocality = "gpsLocality"
        static let gpsTimezone = "gpsTimezone"
        static let gpsLatitude = "gpsLatitude"
        static let gpsLongitude = "gpsLongitude"
        static let gpsCoordinateCached = "gpsCoordinateCached"
        static let gpsDetectedCity = "gpsDetectedCity" // JSON-encoded City
        static let enabledPrayers = "enabledPrayers"
        static let hijriCalendarIdentifier = "hijriCalendarIdentifier"
        static let hijriDayOffset = "hijriDayOffset"
        static let selectedCriterion = "selectedCriterion"
        static let hilalNotificationEnabled = "hilalNotificationEnabled"
        static let liveActivityEnabled = "liveActivityEnabled"
    }

    // MARK: - Keys synced via iCloud KVS

    /// Keys written to NSUbiquitousKeyValueStore on change (excludes device-specific values).
    private static let kvsKeys: Set<String> = [
        Keys.calculationMethod,
        Keys.asrMethod,
        Keys.use24HourTime,
        Keys.uiScale,
        Keys.appearance,
        Keys.locationSource,
        Keys.gpsLocality,
        Keys.gpsTimezone,
        Keys.selectedCityName,
        Keys.selectedCityCountryCode,
        Keys.selectedCityLatitude,
        Keys.selectedCityLongitude,
        Keys.selectedCityTimezone,
        Keys.prayerAdjustments,
        Keys.prayerAdhaanIds,
        Keys.mutedPrayers,
        Keys.enabledPrayers,
        Keys.hijriCalendarIdentifier,
        Keys.hijriDayOffset,
        Keys.selectedCriterion,
        Keys.hilalNotificationEnabled,
        Keys.liveActivityEnabled,
    ]

    @Published public var hasCompletedSetup: Bool {
        didSet {
            defaults.set(hasCompletedSetup, forKey: Keys.hasCompletedSetup)
            // hasCompletedSetup is intentionally NOT synced via KVS —
            // each device completes its own onboarding independently.
        }
    }

    @Published public var calculationMethod: CalculationMethod {
        didSet {
            defaults.set(calculationMethod.rawValue, forKey: Keys.calculationMethod)
            guard !isApplyingRemote else { return }
            kvs.set(calculationMethod.rawValue, forKey: Keys.calculationMethod)
        }
    }

    @Published public var asrMethod: AsrJuristicMethod {
        didSet {
            defaults.set(asrMethod.rawValue, forKey: Keys.asrMethod)
            guard !isApplyingRemote else { return }
            kvs.set(asrMethod.rawValue, forKey: Keys.asrMethod)
        }
    }

    @Published public var use24HourTime: Bool {
        didSet {
            defaults.set(use24HourTime, forKey: Keys.use24HourTime)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            guard !isApplyingRemote else { return }
            kvs.set(use24HourTime, forKey: Keys.use24HourTime)
        }
    }

    /// UI display scale — 0.7 (70%) to 1.5 (150%) in 0.1 increments. Default 1.0.
    @Published public var uiScale: Double {
        didSet {
            defaults.set(uiScale, forKey: Keys.uiScale)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            guard !isApplyingRemote else { return }
            kvs.set(uiScale, forKey: Keys.uiScale)
        }
    }

    @Published public var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            guard !isApplyingRemote else { return }
            kvs.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    @Published public var prayerAdjustments: [String: Int] = [:]

    /// Prayers for which local notifications are enabled. Defaults to the five
    /// canonical prayer times (Sunrise excluded).
    public static let defaultEnabledPrayers: Set<String> = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    @Published public var enabledPrayers: Set<String> {
        didSet {
            let array = Array(enabledPrayers).sorted()
            defaults.set(array, forKey: Keys.enabledPrayers)
            guard !isApplyingRemote else { return }
            kvs.set(array, forKey: Keys.enabledPrayers)
        }
    }

    /// Returns true if local notifications are enabled for the given prayer name.
    public func isPrayerEnabled(_ name: String) -> Bool {
        enabledPrayers.contains(name)
    }

    @Published public var hijriCalendarIdentifier: String {
        didSet {
            defaults.set(hijriCalendarIdentifier, forKey: Keys.hijriCalendarIdentifier)
            guard !isApplyingRemote else { return }
            kvs.set(hijriCalendarIdentifier, forKey: Keys.hijriCalendarIdentifier)
        }
    }

    @Published public var hijriDayOffset: Int {
        didSet {
            defaults.set(hijriDayOffset, forKey: Keys.hijriDayOffset)
            guard !isApplyingRemote else { return }
            kvs.set(hijriDayOffset, forKey: Keys.hijriDayOffset)
        }
    }

    @Published public var selectedCriterion: String {
        didSet {
            defaults.set(selectedCriterion, forKey: Keys.selectedCriterion)
            guard !isApplyingRemote else { return }
            kvs.set(selectedCriterion, forKey: Keys.selectedCriterion)
        }
    }

    @Published public var hilalNotificationEnabled: Bool {
        didSet {
            defaults.set(hilalNotificationEnabled, forKey: Keys.hilalNotificationEnabled)
            guard !isApplyingRemote else { return }
            kvs.set(hilalNotificationEnabled, forKey: Keys.hilalNotificationEnabled)
        }
    }

    /// Controls whether the Live Activity / Dynamic Island prayer countdown is active.
    /// Independent of `hilalNotificationEnabled` — users may want one without the other.
    @Published public var liveActivityEnabled: Bool {
        didSet {
            defaults.set(liveActivityEnabled, forKey: Keys.liveActivityEnabled)
            guard !isApplyingRemote else { return }
            kvs.set(liveActivityEnabled, forKey: Keys.liveActivityEnabled)
        }
    }

    // MARK: - Active location accessors (single source of truth for notifications + widget)

    /// The coordinate to use for prayer-time calculations — GPS if locationSource == "gps",
    /// otherwise the manually selected city's coordinate.
    public var activeCoordinate: CLLocationCoordinate2D? {
        if locationSource == "gps" {
            let lat = defaults.double(forKey: Keys.gpsLatitude)
            let lon = defaults.double(forKey: Keys.gpsLongitude)
            guard lat != 0 || lon != 0 else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return loadCity()?.coordinate
    }

    /// The IANA timezone identifier for the active location.
    public var activeTimezoneIdentifier: String {
        if locationSource == "gps", !gpsTimezone.isEmpty { return gpsTimezone }
        return loadCity()?.timezone ?? TimeZone.current.identifier
    }

    /// The display name for the active location (locality or city name).
    public var activeCityName: String {
        if locationSource == "gps", !gpsLocality.isEmpty { return gpsLocality }
        return loadCity()?.name ?? ""
    }

    @Published public var locationSource: String {
        didSet {
            defaults.set(locationSource, forKey: Keys.locationSource)
            guard !isApplyingRemote else { return }
            kvs.set(locationSource, forKey: Keys.locationSource)
        }
    }

    @Published public var gpsLocality: String {
        didSet {
            defaults.set(gpsLocality, forKey: Keys.gpsLocality)
            guard !isApplyingRemote else { return }
            kvs.set(gpsLocality, forKey: Keys.gpsLocality)
        }
    }

    @Published public var gpsTimezone: String {
        didSet {
            defaults.set(gpsTimezone, forKey: Keys.gpsTimezone)
            guard !isApplyingRemote else { return }
            kvs.set(gpsTimezone, forKey: Keys.gpsTimezone)
        }
    }

    /// The most recently GPS-detected city (precise coords + CLGeocoder locality).
    /// Injected into the city picker so users can select it without it being in cities.json.
    @Published public var gpsDetectedCity: City? {
        didSet {
            if let city = gpsDetectedCity,
               let data = try? JSONEncoder().encode(city) {
                defaults.set(data, forKey: Keys.gpsDetectedCity)
            } else {
                defaults.removeObject(forKey: Keys.gpsDetectedCity)
            }
            // gpsDetectedCity is device-specific (GPS result) — not synced via KVS
        }
    }

    public static let uiScaleMin: Double = 0.7
    public static let uiScaleMax: Double = 1.5
    public static let uiScaleStep: Double = 0.1

    public init(userDefaults: UserDefaults = .standard) {
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

        let savedScale = defaults.double(forKey: Keys.uiScale)
        uiScale = savedScale == 0 ? 1.0 : savedScale // 0 means key not found

        if let raw = userDefaults.string(forKey: Keys.appearance),
           let saved = AppAppearance(rawValue: raw) {
            appearance = saved
        } else {
            appearance = .system
        }

        locationSource = userDefaults.string(forKey: Keys.locationSource) ?? "manual"
        gpsLocality = userDefaults.string(forKey: Keys.gpsLocality) ?? ""
        gpsTimezone = userDefaults.string(forKey: Keys.gpsTimezone) ?? TimeZone.current.identifier
        if let data = userDefaults.data(forKey: Keys.gpsDetectedCity),
           let city = try? JSONDecoder().decode(City.self, from: data) {
            gpsDetectedCity = city
        } else {
            gpsDetectedCity = nil
        }

        if let data = userDefaults.data(forKey: Keys.prayerAdjustments),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            prayerAdjustments = decoded
        } else if let dict = userDefaults.dictionary(forKey: Keys.prayerAdjustments) as? [String: Int] {
            prayerAdjustments = dict
        }

        if let arr = userDefaults.array(forKey: Keys.enabledPrayers) as? [String] {
            enabledPrayers = Set(arr)
        } else {
            enabledPrayers = Self.defaultEnabledPrayers
        }

        hijriCalendarIdentifier = userDefaults.string(forKey: Keys.hijriCalendarIdentifier) ?? "islamic-umalqura"
        hijriDayOffset = userDefaults.integer(forKey: Keys.hijriDayOffset) // defaults to 0
        selectedCriterion = userDefaults.string(forKey: Keys.selectedCriterion) ?? "odeh"
        hilalNotificationEnabled = userDefaults.bool(forKey: Keys.hilalNotificationEnabled)
        liveActivityEnabled = userDefaults.bool(forKey: Keys.liveActivityEnabled)

        // Start KVS sync: subscribe to remote changes and trigger an initial pull.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteKVSChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs
        )
        kvs.synchronize()

        migrateFromStandardDefaultsIfNeeded()
    }

    // MARK: - App Group migration

    private func migrateFromStandardDefaultsIfNeeded() {
        let migrationKey = "didMigrateToAppGroupV1"
        // Skip if already migrated OR if the suite already has meaningful data
        guard !defaults.bool(forKey: migrationKey),
              defaults.dictionaryRepresentation().count <= 2
        else {
            defaults.set(true, forKey: migrationKey)
            return
        }
        let std = UserDefaults.standard
        // Only migrate if standard has setup data to copy
        guard std.bool(forKey: "hasCompletedSetup") else {
            defaults.set(true, forKey: migrationKey)
            return
        }
        let keysToMigrate = [
            "hasCompletedSetup", "selectedCityName", "selectedCityCountryCode",
            "selectedCityLatitude", "selectedCityLongitude", "selectedCityTimezone",
            "calculationMethod", "asrMethod", "prayerAdjustments", "use24HourTime",
            "prayerAdhaanIds", "mutedPrayers", "uiScale", "appAppearance",
            "locationSource", "gpsLocality", "gpsTimezone",
        ]
        for key in keysToMigrate {
            if let value = std.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: migrationKey)
    }

    // MARK: - iCloud KVS remote change handler

    @objc private func handleRemoteKVSChange(_ note: Notification) {
        guard let userInfo = note.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for key in changedKeys where SettingsManager.kvsKeys.contains(key) {
                self.applyRemoteValue(forKey: key)
            }
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    /// Applies a value received from KVS to the local state, suppressing write-back.
    private func applyRemoteValue(forKey key: String) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        switch key {
        case Keys.calculationMethod:
            if let raw = kvs.string(forKey: key),
               let method = CalculationMethod(rawValue: raw) {
                calculationMethod = method
            }
        case Keys.asrMethod:
            if let raw = kvs.string(forKey: key),
               let asr = AsrJuristicMethod(rawValue: raw) {
                asrMethod = asr
            }
        case Keys.use24HourTime:
            use24HourTime = kvs.bool(forKey: key)
        case Keys.uiScale:
            let v = kvs.double(forKey: key)
            if v > 0 { uiScale = v }
        case Keys.appearance:
            if let raw = kvs.string(forKey: key),
               let a = AppAppearance(rawValue: raw) {
                appearance = a
            }
        case Keys.locationSource:
            if let v = kvs.string(forKey: key) { locationSource = v }
        case Keys.gpsLocality:
            if let v = kvs.string(forKey: key) { gpsLocality = v }
        case Keys.gpsTimezone:
            if let v = kvs.string(forKey: key) { gpsTimezone = v }
        case Keys.selectedCityName, Keys.selectedCityCountryCode,
             Keys.selectedCityLatitude, Keys.selectedCityLongitude,
             Keys.selectedCityTimezone:
            // Re-assemble city from individual KVS fields and persist locally
            applyRemoteCityFromKVS()
        case Keys.prayerAdjustments:
            if let data = kvs.data(forKey: key),
               let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
                prayerAdjustments = decoded
                defaults.set(data, forKey: key)
            }
        case Keys.prayerAdhaanIds:
            if let dict = kvs.dictionary(forKey: key) as? [String: String] {
                defaults.set(dict, forKey: key)
            }
        case Keys.mutedPrayers:
            if let arr = kvs.array(forKey: key) as? [String] {
                defaults.set(arr, forKey: key)
            }
        case Keys.enabledPrayers:
            if let arr = kvs.array(forKey: key) as? [String] {
                enabledPrayers = Set(arr)
            }
        case Keys.hijriCalendarIdentifier:
            if let v = kvs.string(forKey: key) { hijriCalendarIdentifier = v }
        case Keys.hijriDayOffset:
            hijriDayOffset = Int(kvs.longLong(forKey: key))
        case Keys.selectedCriterion:
            if let v = kvs.string(forKey: key) { selectedCriterion = v }
        case Keys.hilalNotificationEnabled:
            hilalNotificationEnabled = kvs.bool(forKey: key)
        case Keys.liveActivityEnabled:
            liveActivityEnabled = kvs.bool(forKey: key)
        default:
            break
        }
    }

    private func applyRemoteCityFromKVS() {
        guard let name = kvs.string(forKey: Keys.selectedCityName),
              let countryCode = kvs.string(forKey: Keys.selectedCityCountryCode),
              let timezone = kvs.string(forKey: Keys.selectedCityTimezone)
        else { return }
        let lat = kvs.double(forKey: Keys.selectedCityLatitude)
        let lon = kvs.double(forKey: Keys.selectedCityLongitude)
        guard lat != 0 || lon != 0 else { return }

        defaults.set(name, forKey: Keys.selectedCityName)
        defaults.set(countryCode, forKey: Keys.selectedCityCountryCode)
        defaults.set(lat, forKey: Keys.selectedCityLatitude)
        defaults.set(lon, forKey: Keys.selectedCityLongitude)
        defaults.set(timezone, forKey: Keys.selectedCityTimezone)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    // MARK: - City persistence

    public func saveCity(_ city: City) {
        defaults.set(city.name, forKey: Keys.selectedCityName)
        defaults.set(city.countryCode, forKey: Keys.selectedCityCountryCode)
        defaults.set(city.latitude, forKey: Keys.selectedCityLatitude)
        defaults.set(city.longitude, forKey: Keys.selectedCityLongitude)
        defaults.set(city.timezone, forKey: Keys.selectedCityTimezone)
        // Sync city to KVS so the other device picks it up
        kvs.set(city.name, forKey: Keys.selectedCityName)
        kvs.set(city.countryCode, forKey: Keys.selectedCityCountryCode)
        kvs.set(city.latitude, forKey: Keys.selectedCityLatitude)
        kvs.set(city.longitude, forKey: Keys.selectedCityLongitude)
        kvs.set(city.timezone, forKey: Keys.selectedCityTimezone)
    }

    public func loadCity() -> City? {
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

    public func saveGPSCoordinates(_ coordinate: CLLocationCoordinate2D) {
        defaults.set(coordinate.latitude, forKey: Keys.gpsLatitude)
        defaults.set(coordinate.longitude, forKey: Keys.gpsLongitude)
        defaults.set(true, forKey: Keys.gpsCoordinateCached)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        // GPS coordinates are device-specific — not synced via KVS
    }

    public func cachedGPSCoordinate() -> CLLocationCoordinate2D? {
        guard defaults.bool(forKey: Keys.gpsCoordinateCached) else { return nil }
        let lat = defaults.double(forKey: Keys.gpsLatitude)
        let lon = defaults.double(forKey: Keys.gpsLongitude)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public func completeSetup(city: City, calculationMethod: CalculationMethod, asrMethod: AsrJuristicMethod) {
        saveCity(city)
        self.calculationMethod = calculationMethod
        self.asrMethod = asrMethod
        hasCompletedSetup = true

        // Notify that settings changed so menu bar can update
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    public func resetSettings() {
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

    public func getAdjustment(for prayerName: String) -> Int {
        let adjustments = defaults.dictionary(forKey: Keys.prayerAdjustments) as? [String: Int] ?? [:]
        return adjustments[prayerName] ?? 0
    }

    // MARK: - Adhaan Selection

    public func getAdhaan(for prayerName: String) -> Adhaan {
        let map = defaults.dictionary(forKey: Keys.prayerAdhaanIds) as? [String: String] ?? [:]
        let id = map[prayerName] ?? "silent"
        return Adhaan.available.first { $0.id == id } ?? .silent
    }

    public func setAdhaan(_ adhaan: Adhaan, for prayerName: String) {
        var map = defaults.dictionary(forKey: Keys.prayerAdhaanIds) as? [String: String] ?? [:]
        map[prayerName] = adhaan.id
        defaults.set(map, forKey: Keys.prayerAdhaanIds)
        kvs.set(map, forKey: Keys.prayerAdhaanIds)
    }

    // MARK: - Per-Prayer Mute

    public func isPrayerMuted(_ prayerName: String) -> Bool {
        let arr = defaults.stringArray(forKey: Keys.mutedPrayers) ?? []
        return arr.contains(prayerName)
    }

    public func setPrayerMuted(_ muted: Bool, for prayerName: String) {
        var set = Set(defaults.stringArray(forKey: Keys.mutedPrayers) ?? [])
        if muted { set.insert(prayerName) } else { set.remove(prayerName) }
        let arr = Array(set)
        defaults.set(arr, forKey: Keys.mutedPrayers)
        kvs.set(arr, forKey: Keys.mutedPrayers)
    }

    public func setAdjustment(_ minutes: Int, for prayerName: String) {
        var adjustments = defaults.dictionary(forKey: Keys.prayerAdjustments) as? [String: Int] ?? [:]
        adjustments[prayerName] = minutes
        defaults.set(adjustments, forKey: Keys.prayerAdjustments)
        prayerAdjustments[prayerName] = minutes
        if let data = try? JSONEncoder().encode(adjustments) {
            kvs.set(data, forKey: Keys.prayerAdjustments)
        }
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    public func hasAnyAdjustments() -> Bool {
        let adjustments = defaults.dictionary(forKey: Keys.prayerAdjustments) as? [String: Int] ?? [:]
        return adjustments.values.contains { $0 != 0 }
    }

    public func resetAdjustments() {
        defaults.removeObject(forKey: Keys.prayerAdjustments)
        kvs.removeObject(forKey: Keys.prayerAdjustments)
        prayerAdjustments = [:]
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}

public extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
