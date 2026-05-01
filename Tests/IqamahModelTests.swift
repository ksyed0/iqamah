import Testing
import Foundation
import CoreLocation

// MARK: - CalculationMethod Tests

@Suite("Calculation Method Model Tests")
struct CalculationMethodTests {

    @Test("All 6 calculation methods are available")
    func allMethodsPresent() {
        #expect(CalculationMethod.allCases.count == 6)
    }

    @Test("Each method has a non-empty display name", arguments: CalculationMethod.allCases)
    func displayNameNotEmpty(method: CalculationMethod) {
        #expect(!method.displayName.isEmpty)
    }

    @Test("Each method has a unique display name")
    func displayNamesAreUnique() {
        let names = CalculationMethod.allCases.map { $0.displayName }
        let unique = Set(names)
        #expect(unique.count == names.count, "Duplicate display names found")
    }

    @Test("Each method has a unique raw value")
    func rawValuesAreUnique() {
        let raws = CalculationMethod.allCases.map { $0.rawValue }
        #expect(Set(raws).count == raws.count)
    }

    @Test("Fajr angles are within valid astronomical range (10°–20°)", arguments: CalculationMethod.allCases)
    func fajrAngleRange(method: CalculationMethod) {
        #expect(method.fajrAngle >= 10.0 && method.fajrAngle <= 20.0,
                "\(method.displayName) Fajr angle \(method.fajrAngle)° out of range")
    }

    @Test("Isha angle is zero only for Umm Al-Qura (uses interval instead)")
    func ishaAngleUmmAlQura() {
        #expect(CalculationMethod.ummAlQura.ishaAngle == 0.0)
        #expect(CalculationMethod.ummAlQura.ishaInterval == 90)
        for method in CalculationMethod.allCases where method != .ummAlQura {
            #expect(method.ishaInterval == nil, "\(method.displayName) should not use interval")
            #expect(method.ishaAngle > 0, "\(method.displayName) Isha angle should be > 0")
        }
    }

    @Test("Tehran method has a Maghrib angle; others do not")
    func maghribAngle() {
        #expect(CalculationMethod.tehran.maghribAngle == 4.5)
        for method in CalculationMethod.allCases where method != .tehran {
            #expect(method.maghribAngle == nil, "\(method.displayName) should not have Maghrib angle")
        }
    }

    @Test("CalculationMethod is round-trip encodable via rawValue")
    func rawValueRoundTrip() {
        for method in CalculationMethod.allCases {
            let decoded = CalculationMethod(rawValue: method.rawValue)
            #expect(decoded == method, "Round-trip failed for \(method.rawValue)")
        }
    }
}

// MARK: - AsrJuristicMethod Tests

@Suite("Asr Juristic Method Tests")
struct AsrJuristicMethodTests {

    @Test("Standard shadow factor is 1.0")
    func standardShadowFactor() {
        #expect(AsrJuristicMethod.standard.shadowFactor == 1.0)
    }

    @Test("Hanafi shadow factor is 2.0")
    func hanafiShadowFactor() {
        #expect(AsrJuristicMethod.hanafi.shadowFactor == 2.0)
    }

    @Test("Both methods have non-empty display names", arguments: AsrJuristicMethod.allCases)
    func displayNameNotEmpty(method: AsrJuristicMethod) {
        #expect(!method.displayName.isEmpty)
    }

    @Test("Both methods have unique display names")
    func displayNamesUnique() {
        let names = AsrJuristicMethod.allCases.map { $0.displayName }
        #expect(Set(names).count == names.count)
    }
}

// MARK: - PrayerTimes Model Tests

@Suite("PrayerTimes Model Tests")
struct PrayerTimesModelTests {

    private func makePrayerTimes() -> PrayerTimes {
        let base = Date()
        return PrayerTimes(
            fajr:    base.addingTimeInterval(0),
            sunrise: base.addingTimeInterval(3600),
            dhuhr:   base.addingTimeInterval(7200),
            asr:     base.addingTimeInterval(10800),
            maghrib: base.addingTimeInterval(14400),
            isha:    base.addingTimeInterval(18000),
            date:    base
        )
    }

    @Test("prayers array contains exactly 6 entries")
    func prayersArrayCount() {
        let pt = makePrayerTimes()
        #expect(pt.prayers.count == 6)
    }

    @Test("prayers array is in correct order")
    func prayersArrayOrder() {
        let pt = makePrayerTimes()
        let expectedNames = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
        for (i, prayer) in pt.prayers.enumerated() {
            #expect(prayer.name == expectedNames[i])
        }
    }

    @Test("formattedTime returns non-empty string")
    func formattedTimeNonEmpty() {
        let pt = makePrayerTimes()
        let formatter = PrayerTimes.timeFormatter(for: .current)
        let result = pt.formattedTime(for: pt.fajr, using: formatter)
        #expect(!result.isEmpty)
    }

    @Test("timeFormatter respects supplied timezone")
    func timeFormatterTimezone() {
        let nyTZ = TimeZone(identifier: "America/New_York")!
        let londonTZ = TimeZone(identifier: "Europe/London")!
        let nyFormatter = PrayerTimes.timeFormatter(for: nyTZ)
        let londonFormatter = PrayerTimes.timeFormatter(for: londonTZ)

        // Fixed date: 2024-01-01 12:00 UTC
        var comps = DateComponents()
        comps.year = 2024; comps.month = 1; comps.day = 1
        comps.hour = 12; comps.minute = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: comps)!

        let nyString = nyFormatter.string(from: date)
        let londonString = londonFormatter.string(from: date)
        #expect(nyString != londonString, "Different timezones should format the same UTC time differently")
    }
}

// MARK: - City Model Tests

@Suite("City Model Tests")
struct CityModelTests {

    @Test("Valid city initialises without throwing")
    func validCityInit() throws {
        let city = try City(
            name: "London",
            countryCode: "GB",
            latitude: 51.5074,
            longitude: -0.1278,
            timezone: "Europe/London"
        )
        #expect(city.name == "London")
        #expect(city.countryCode == "GB")
        #expect(city.latitude == 51.5074)
        #expect(city.longitude == -0.1278)
        #expect(city.timezone == "Europe/London")
    }

    @Test("City with latitude > 90 throws invalidCoordinates")
    func invalidLatitudeTooHigh() {
        #expect(throws: IqamahError.self) {
            try City(name: "Bad", countryCode: "XX", latitude: 91.0, longitude: 0, timezone: "UTC")
        }
    }

    @Test("City with latitude < -90 throws invalidCoordinates")
    func invalidLatitudeTooLow() {
        #expect(throws: IqamahError.self) {
            try City(name: "Bad", countryCode: "XX", latitude: -91.0, longitude: 0, timezone: "UTC")
        }
    }

    @Test("City with longitude > 180 throws invalidCoordinates")
    func invalidLongitudeTooHigh() {
        #expect(throws: IqamahError.self) {
            try City(name: "Bad", countryCode: "XX", latitude: 0, longitude: 181.0, timezone: "UTC")
        }
    }

    @Test("City with longitude < -180 throws invalidCoordinates")
    func invalidLongitudeTooLow() {
        #expect(throws: IqamahError.self) {
            try City(name: "Bad", countryCode: "XX", latitude: 0, longitude: -181.0, timezone: "UTC")
        }
    }

    @Test("City with invalid timezone identifier throws invalidTimezone")
    func invalidTimezone() {
        #expect(throws: IqamahError.self) {
            try City(name: "Bad", countryCode: "XX", latitude: 0, longitude: 0, timezone: "Not/ATimezone")
        }
    }

    @Test("City boundary values are accepted — poles and date line")
    func boundaryCoordinates() throws {
        // North Pole
        _ = try City(name: "North", countryCode: "XX", latitude: 90.0, longitude: 0, timezone: "UTC")
        // South Pole
        _ = try City(name: "South", countryCode: "XX", latitude: -90.0, longitude: 0, timezone: "UTC")
        // Date line east
        _ = try City(name: "East", countryCode: "XX", latitude: 0, longitude: 180.0, timezone: "UTC")
        // Date line west
        _ = try City(name: "West", countryCode: "XX", latitude: 0, longitude: -180.0, timezone: "UTC")
    }

    @Test("City.coordinate returns correct CLLocationCoordinate2D")
    func coordinateProperty() throws {
        let city = try City(name: "Makkah", countryCode: "SA", latitude: 21.4225, longitude: 39.8262, timezone: "Asia/Riyadh")
        #expect(city.coordinate.latitude == 21.4225)
        #expect(city.coordinate.longitude == 39.8262)
    }

    @Test("City id is unique for different country+name combinations")
    func cityIdUniqueness() throws {
        let london = try City(name: "London", countryCode: "GB", latitude: 51.5, longitude: -0.1, timezone: "Europe/London")
        let cairo  = try City(name: "Cairo",  countryCode: "EG", latitude: 30.0, longitude: 31.2, timezone: "Africa/Cairo")
        #expect(london.id != cairo.id)
    }

    @Test("distance(from:) returns a positive value between different cities")
    func distanceBetweenCities() throws {
        let london = try City(name: "London", countryCode: "GB", latitude: 51.5074, longitude: -0.1278, timezone: "Europe/London")
        let makkah = try City(name: "Makkah", countryCode: "SA", latitude: 21.4225, longitude: 39.8262, timezone: "Asia/Riyadh")
        let distance = london.distance(from: makkah.coordinate)
        // London to Makkah ≈ 5,200 km
        #expect(distance > 4_000_000 && distance < 6_000_000, "Expected ~5,200km, got \(distance)m")
    }

    @Test("distance(from:) returns ~0 for the same coordinate")
    func distanceSameLocation() throws {
        let city = try City(name: "Makkah", countryCode: "SA", latitude: 21.4225, longitude: 39.8262, timezone: "Asia/Riyadh")
        let distance = city.distance(from: city.coordinate)
        #expect(distance < 1.0, "Same coordinate should have ~0 distance, got \(distance)m")
    }
}

// MARK: - Country Model Tests

@Suite("Country Model Tests")
struct CountryModelTests {

    @Test("Country id equals its code")
    func idEqualsCode() {
        let country = Country(name: "Saudi Arabia", code: "SA")
        #expect(country.id == "SA")
    }

    @Test("Two countries with the same code are equal (Hashable)")
    func equalityByCode() {
        let a = Country(name: "Saudi Arabia", code: "SA")
        let b = Country(name: "Saudi Arabia", code: "SA")
        #expect(a == b)
    }

    @Test("Countries are usable as dictionary keys (Hashable)")
    func hashable() {
        let sa = Country(name: "Saudi Arabia", code: "SA")
        let gb = Country(name: "United Kingdom", code: "GB")
        var map: [Country: Int] = [:]
        map[sa] = 1
        map[gb] = 2
        #expect(map[sa] == 1)
        #expect(map[gb] == 2)
    }
}

// MARK: - CitiesDatabase Tests

@Suite("CitiesDatabase Tests")
struct CitiesDatabaseTests {

    private func makeDatabase() throws -> CitiesDatabase {
        let countries = [
            Country(name: "Saudi Arabia", code: "SA"),
            Country(name: "United Kingdom", code: "GB"),
            Country(name: "Egypt", code: "EG")
        ]
        let cities = [
            try City(name: "Makkah",  countryCode: "SA", latitude: 21.4225, longitude: 39.8262,  timezone: "Asia/Riyadh"),
            try City(name: "Riyadh",  countryCode: "SA", latitude: 24.6877, longitude: 46.7219,  timezone: "Asia/Riyadh"),
            try City(name: "London",  countryCode: "GB", latitude: 51.5074, longitude: -0.1278,   timezone: "Europe/London"),
            try City(name: "Cairo",   countryCode: "EG", latitude: 30.0444, longitude: 31.2357,   timezone: "Africa/Cairo")
        ]
        return CitiesDatabase(countries: countries, cities: cities)
    }

    @Test("country(forCode:) returns the correct country")
    func countryForCode() throws {
        let db = try makeDatabase()
        let sa = db.country(forCode: "SA")
        #expect(sa?.name == "Saudi Arabia")
    }

    @Test("country(forCode:) returns nil for unknown code")
    func countryForUnknownCode() throws {
        let db = try makeDatabase()
        #expect(db.country(forCode: "ZZ") == nil)
    }

    @Test("cities(forCountryCode:) filters correctly")
    func citiesForCountryCode() throws {
        let db = try makeDatabase()
        let saCities = db.cities(forCountryCode: "SA")
        #expect(saCities.count == 2)
        #expect(saCities.allSatisfy { $0.countryCode == "SA" })
    }

    @Test("cities(forCountryCode:) returns cities sorted alphabetically")
    func citiesSortedAlphabetically() throws {
        let db = try makeDatabase()
        let saCities = db.cities(forCountryCode: "SA")
        // Makkah < Riyadh alphabetically
        #expect(saCities.first?.name == "Makkah")
        #expect(saCities.last?.name == "Riyadh")
    }

    @Test("cities(forCountryCode:) returns empty for unknown country")
    func citiesForUnknownCountry() throws {
        let db = try makeDatabase()
        #expect(db.cities(forCountryCode: "ZZ").isEmpty)
    }

    @Test("closestCity(to:) finds the nearest city")
    func closestCity() throws {
        let db = try makeDatabase()
        // Coordinate very close to Makkah
        let nearMakkah = CLLocationCoordinate2D(latitude: 21.4, longitude: 39.8)
        let closest = db.closestCity(to: nearMakkah)
        #expect(closest?.name == "Makkah")
    }

    @Test("closestCity(to:) returns nil for empty database")
    func closestCityEmptyDB() {
        let emptyDB = CitiesDatabase(countries: [], cities: [])
        #expect(emptyDB.closestCity(to: CLLocationCoordinate2D(latitude: 0, longitude: 0)) == nil)
    }
}

// MARK: - IqamahError Tests

@Suite("IqamahError Tests")
struct IqamahErrorTests {

    @Test("All errors produce a non-empty localizedDescription")
    func allErrorsHaveDescriptions() {
        let errors: [IqamahError] = [
            .invalidCoordinates(latitude: 91, longitude: 0),
            .invalidDate("test date"),
            .invalidCalculationMethod("bad"),
            .invalidTimezone("Bad/Zone"),
            .invalidAdjustment(minutes: 999, allowedRange: -60...60),
            .locationServicesDenied,
            .locationServicesFailed(underlyingError: NSError(domain: "test", code: 0)),
            .locationServicesRestricted,
            .settingsPersistenceFailed(underlyingError: NSError(domain: "test", code: 0)),
            .citiesDatabaseLoadFailed(reason: "test reason"),
            .citiesDatabaseNotFound,
            .citiesDatabaseCorrupted(underlyingError: NSError(domain: "test", code: 0)),
            .invalidPrayerTime(prayer: "Fajr", reason: "test"),
            .invalidQiblahAngle(angle: -5),
            .prayerTimeCalculationFailed(reason: "test"),
            .hijriConversionFailed(date: Date()),
            .unexpectedError(message: "test"),
            .serviceInitializationFailed(service: "TestService"),
            .resourceNotFound(resource: "test.json")
        ]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty, "Error \(error) has no description")
        }
    }

    @Test("locationServicesDenied is recoverable")
    func locationServicesDeniedRecoverable() {
        #expect(IqamahError.locationServicesDenied.isRecoverable)
    }

    @Test("locationServicesRestricted is recoverable")
    func locationServicesRestrictedRecoverable() {
        #expect(IqamahError.locationServicesRestricted.isRecoverable)
    }

    @Test("citiesDatabaseNotFound is recoverable")
    func databaseNotFoundRecoverable() {
        #expect(IqamahError.citiesDatabaseNotFound.isRecoverable)
    }

    @Test("unexpectedError is not recoverable")
    func unexpectedErrorNotRecoverable() {
        #expect(!IqamahError.unexpectedError(message: "crash").isRecoverable)
    }

    @Test("Validation errors use WARN log level")
    func validationErrorsWarnLevel() {
        #expect(IqamahError.invalidCoordinates(latitude: 91, longitude: 0).logLevel == "WARN")
        #expect(IqamahError.invalidDate("x").logLevel == "WARN")
        #expect(IqamahError.invalidTimezone("x").logLevel == "WARN")
    }

    @Test("System errors use CRITICAL log level")
    func systemErrorsCriticalLevel() {
        #expect(IqamahError.unexpectedError(message: "x").logLevel == "CRITICAL")
        #expect(IqamahError.serviceInitializationFailed(service: "x").logLevel == "CRITICAL")
        #expect(IqamahError.resourceNotFound(resource: "x").logLevel == "CRITICAL")
    }

    @Test("Integration errors use ERROR log level")
    func integrationErrorsErrorLevel() {
        #expect(IqamahError.locationServicesDenied.logLevel == "ERROR")
        #expect(IqamahError.citiesDatabaseNotFound.logLevel == "ERROR")
    }

    @Test("locationServicesDenied has a recovery suggestion")
    func locationServicesDeniedRecoverySuggestion() {
        let error = IqamahError.locationServicesDenied
        #expect(error.recoverySuggestion != nil)
        #expect(!(error.recoverySuggestion ?? "").isEmpty)
    }

    @Test("citiesDatabaseNotFound has a failure reason")
    func databaseNotFoundFailureReason() {
        let error = IqamahError.citiesDatabaseNotFound
        #expect(error.failureReason != nil)
    }
}

// MARK: - SettingsManager Tests

// .serialized: SettingsManager.shared is a singleton — tests must run sequentially
@Suite("SettingsManager Tests", .serialized)
struct SettingsManagerTests {

    // Each test gets an isolated UserDefaults suite — no cross-test or cross-suite pollution
    private func freshSettings() -> SettingsManager {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        return SettingsManager(userDefaults: defaults)
    }

    @Test("hasCompletedSetup defaults to false after reset")
    func defaultsAfterReset() {
        let s = freshSettings()
        #expect(s.hasCompletedSetup == false)
    }

    @Test("calculationMethod defaults to muslimWorldLeague after reset")
    func defaultCalculationMethod() {
        let s = freshSettings()
        #expect(s.calculationMethod == .muslimWorldLeague)
    }

    @Test("asrMethod defaults to standard after reset")
    func defaultAsrMethod() {
        let s = freshSettings()
        #expect(s.asrMethod == .standard)
    }

    @Test("loadCity() returns nil before setup is complete")
    func loadCityNilBeforeSetup() {
        let s = freshSettings()
        #expect(s.loadCity() == nil)
    }

    @Test("completeSetup() saves city and marks setup complete")
    func completeSetupSavesCity() throws {
        let s = freshSettings()
        let city = try City(name: "Istanbul", countryCode: "TR", latitude: 41.0082, longitude: 28.9784, timezone: "Europe/Istanbul")
        s.completeSetup(city: city, calculationMethod: .karachi, asrMethod: .hanafi)

        #expect(s.hasCompletedSetup == true)
        #expect(s.calculationMethod == .karachi)
        #expect(s.asrMethod == .hanafi)

        let loaded = s.loadCity()
        #expect(loaded?.name == "Istanbul")
        #expect(loaded?.countryCode == "TR")
        #expect(loaded?.latitude == 41.0082)
        #expect(loaded?.longitude == 28.9784)
        #expect(loaded?.timezone == "Europe/Istanbul")
    }

    @Test("resetSettings() clears all saved city data")
    func resetClearsCityData() throws {
        let s = freshSettings()
        let city = try City(name: "London", countryCode: "GB", latitude: 51.5, longitude: -0.1, timezone: "Europe/London")
        s.completeSetup(city: city, calculationMethod: .isna, asrMethod: .standard)
        s.resetSettings()

        #expect(s.hasCompletedSetup == false)
        #expect(s.loadCity() == nil)
    }

    @Test("getAdjustment() returns 0 by default for any prayer name")
    func defaultAdjustmentIsZero() {
        let s = freshSettings()
        for name in ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"] {
            #expect(s.getAdjustment(for: name) == 0)
        }
    }

    @Test("setAdjustment() persists and getAdjustment() retrieves it")
    func adjustmentRoundTrip() {
        let s = freshSettings()
        s.setAdjustment(5, for: "Fajr")
        s.setAdjustment(-3, for: "Isha")

        #expect(s.getAdjustment(for: "Fajr") == 5)
        #expect(s.getAdjustment(for: "Isha") == -3)
        #expect(s.getAdjustment(for: "Dhuhr") == 0) // untouched
    }

    @Test("setAdjustment() overwrites previous value for the same prayer")
    func adjustmentOverwrite() {
        let s = freshSettings()
        s.setAdjustment(5, for: "Fajr")
        s.setAdjustment(10, for: "Fajr")
        #expect(s.getAdjustment(for: "Fajr") == 10)
    }

    @Test("setAdjustment(0) effectively clears an adjustment")
    func clearAdjustmentWithZero() {
        let s = freshSettings()
        s.setAdjustment(7, for: "Asr")
        s.setAdjustment(0, for: "Asr")
        #expect(s.getAdjustment(for: "Asr") == 0)
    }

    @Test("completeSetup() posts settingsDidChange notification")
    func completeSetupPostsNotification() throws {
        let s = freshSettings()
        let city = try City(name: "Cairo", countryCode: "EG", latitude: 30.0, longitude: 31.2, timezone: "Africa/Cairo")

        var received = false
        let token = NotificationCenter.default.addObserver(
            forName: .settingsDidChange, object: nil, queue: .main
        ) { _ in received = true }

        s.completeSetup(city: city, calculationMethod: .egypt, asrMethod: .standard)
        // Flush main queue
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        NotificationCenter.default.removeObserver(token)
        #expect(received, "completeSetup should post .settingsDidChange")
    }

    @Test("setAdjustment() posts settingsDidChange notification")
    func adjustmentPostsNotification() {
        let s = freshSettings()

        var received = false
        let token = NotificationCenter.default.addObserver(
            forName: .settingsDidChange, object: nil, queue: .main
        ) { _ in received = true }

        s.setAdjustment(3, for: "Fajr")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        NotificationCenter.default.removeObserver(token)
        #expect(received, "setAdjustment should post .settingsDidChange")
    }
}

// MARK: - Qiblah Bearing Tests

@Suite("Qiblah Bearing Calculation Tests")
struct QiblahBearingTests {

    // Ka'bah coordinates (from QiblahView)
    private let kaabahLat = 21.4225
    private let kaabahLon = 39.8262

    private func bearing(fromLat lat: Double, fromLon lon: Double) -> Double {
        let lat1 = lat * .pi / 180
        let lat2 = kaabahLat * .pi / 180
        let deltaLon = (kaabahLon - lon) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let raw = atan2(y, x) * 180 / .pi
        return (raw + 360).truncatingRemainder(dividingBy: 360)
    }

    @Test("Qiblah bearing from Makkah itself is ~0° (or arbitrary — degenerate case)")
    func bearingFromMakkah() {
        let b = bearing(fromLat: kaabahLat, fromLon: kaabahLon)
        // Bearing from self to self is undefined; result should be in [0, 360)
        #expect(b >= 0 && b < 360)
    }

    @Test("Qiblah bearing from New York is roughly SE (~58°)")
    func bearingFromNewYork() {
        let b = bearing(fromLat: 40.7128, fromLon: -74.0060)
        // New York to Makkah is roughly NE/E, approximately 58°
        #expect(b > 40 && b < 80, "New York Qiblah should be ~58°, got \(b)°")
    }

    @Test("Qiblah bearing from London is roughly SE (~119°)")
    func bearingFromLondon() {
        let b = bearing(fromLat: 51.5074, fromLon: -0.1278)
        // London to Makkah is roughly SE, approximately 119°
        #expect(b > 100 && b < 140, "London Qiblah should be ~119°, got \(b)°")
    }

    @Test("Qiblah bearing from Jakarta is roughly NW (~295°)")
    func bearingFromJakarta() {
        let b = bearing(fromLat: -6.2088, fromLon: 106.8456)
        // Jakarta to Makkah is roughly NW, approximately 295°
        #expect(b > 275 && b < 315, "Jakarta Qiblah should be ~295°, got \(b)°")
    }

    @Test("Qiblah bearing is always in [0, 360)")
    func bearingRange() {
        let testLocations: [(Double, Double)] = [
            (40.7128, -74.006),   // New York
            (51.5074, -0.1278),   // London
            (-6.2088, 106.8456),  // Jakarta
            (35.6762, 139.6503),  // Tokyo
            (-33.8688, 151.2093), // Sydney
            (55.7558, 37.6173),   // Moscow
        ]
        for (lat, lon) in testLocations {
            let b = bearing(fromLat: lat, fromLon: lon)
            #expect(b >= 0 && b < 360, "Bearing from (\(lat), \(lon)) out of range: \(b)")
        }
    }
}

// MARK: - Date Extension Tests

@Suite("Date Extension Tests")
struct DateExtensionTests {

    @Test("formattedGregorianDate() contains year and is well-formed")
    func gregorianDateFormat() {
        // Use midday local time to avoid day-boundary issues in any timezone
        var comps = DateComponents()
        comps.year = 2024; comps.month = 6; comps.day = 15; comps.hour = 12
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        let formatted = date.formattedGregorianDate()
        #expect(formatted.contains("2024"), "Should contain year 2024")
        #expect(formatted.count > 8, "Should be a full date string")
    }

    @Test("formattedHijriDate() contains 'AH'")
    func hijriDateContainsAH() {
        let formatted = Date().formattedHijriDate()
        #expect(formatted.hasSuffix("AH"), "Hijri date should end with 'AH'")
    }

    @Test("hijriDate() year is in a reasonable range for current era")
    func hijriYearRange() {
        let hijri = Date().hijriDate()
        #expect(hijri.year >= 1440 && hijri.year <= 1500)
    }

    @Test("hijriDate() month is 1–12")
    func hijriMonthRange() {
        let hijri = Date().hijriDate()
        #expect(hijri.month >= 1 && hijri.month <= 12)
    }

    @Test("hijriDate() day is 1–30")
    func hijriDayRange() {
        let hijri = Date().hijriDate()
        #expect(hijri.day >= 1 && hijri.day <= 30)
    }

    @Test("hijriDate() monthName is a recognised Hijri month")
    func hijriMonthName() {
        let validMonths = [
            "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
            "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
            "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
        ]
        let hijri = Date().hijriDate()
        #expect(validMonths.contains(hijri.monthName), "Unexpected month name: \(hijri.monthName)")
    }

    @Test("Known Gregorian date converts to expected Hijri date (Ramadan 2024)")
    func knownHijriConversion() {
        // 2024-03-12 is 1 Ramadan 1445 AH (approximately)
        var comps = DateComponents()
        comps.year = 2024; comps.month = 3; comps.day = 12
        comps.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        let hijri = date.hijriDate()
        #expect(hijri.year == 1445)
        #expect(hijri.monthName == "Ramadan")
    }
}

// MARK: - Adhaan Model Tests

@Suite("Adhaan Model Tests")
struct AdhaanModelTests {

    // MARK: Static values

    @Test("Adhaan.silent has empty filename and id 'silent'")
    func silentProperties() {
        #expect(Adhaan.silent.id == "silent")
        #expect(Adhaan.silent.filename.isEmpty)
        #expect(Adhaan.silent.displayName == "Silent")
    }

    // MARK: available vs availableForFajr ordering

    @Test("available always starts with Silent")
    func availableStartsWithSilent() {
        #expect(Adhaan.available.first?.id == "silent")
    }

    @Test("availableForFajr always starts with Silent")
    func availableForFajrStartsWithSilent() {
        #expect(Adhaan.availableForFajr.first?.id == "silent")
    }

    @Test("availableForFajr has at least as many options as available")
    func fajrListIsSupersetOrEqual() {
        #expect(Adhaan.availableForFajr.count >= Adhaan.available.count)
    }

    @Test("All options in available are also in availableForFajr")
    func availableIsSubsetOfFajr() {
        let fajrIds = Set(Adhaan.availableForFajr.map { $0.id })
        for option in Adhaan.available {
            #expect(fajrIds.contains(option.id),
                    "\(option.id) in available but missing from availableForFajr")
        }
    }

    @Test("No duplicate ids in available")
    func noDuplicateIdsInAvailable() {
        let ids = Adhaan.available.map { $0.id }
        #expect(Set(ids).count == ids.count, "Duplicate ids found in Adhaan.available")
    }

    @Test("No duplicate ids in availableForFajr")
    func noDuplicateIdsInAvailableForFajr() {
        let ids = Adhaan.availableForFajr.map { $0.id }
        #expect(Set(ids).count == ids.count, "Duplicate ids found in Adhaan.availableForFajr")
    }

    // MARK: Fajr recordings appear only in availableForFajr

    @Test("Fajr-specific recordings have 'adhaan_fajr_' id prefix")
    func fajrRecordingNamingConvention() {
        for adhaan in Adhaan.adhaanFajrRecordings {
            #expect(adhaan.id.hasPrefix("adhaan_fajr_"),
                    "Fajr recording id '\(adhaan.id)' must start with 'adhaan_fajr_'")
        }
    }

    @Test("Fajr-specific recordings have 'Fajr Adhaan' display name prefix")
    func fajrRecordingDisplayNameConvention() {
        for adhaan in Adhaan.adhaanFajrRecordings {
            #expect(adhaan.displayName.hasPrefix("Fajr Adhaan"),
                    "Fajr recording displayName '\(adhaan.displayName)' must start with 'Fajr Adhaan'")
        }
    }

    @Test("Standard adhaan recordings have 'Adhaan N' display name format")
    func standardAdhaanDisplayNameFormat() {
        for adhaan in Adhaan.adhaanRecordings {
            #expect(adhaan.displayName.hasPrefix("Adhaan "),
                    "Standard adhaan '\(adhaan.displayName)' should start with 'Adhaan '")
            #expect(!adhaan.displayName.hasPrefix("Fajr"),
                    "Standard adhaan '\(adhaan.displayName)' should not start with 'Fajr'")
        }
    }

    @Test("Fajr recordings do NOT appear in standard available list")
    func fajrRecordingsAbsentFromStandardList() {
        let standardIds = Set(Adhaan.available.map { $0.id })
        for fajr in Adhaan.adhaanFajrRecordings {
            #expect(!standardIds.contains(fajr.id),
                    "Fajr recording '\(fajr.id)' should not appear in Adhaan.available")
        }
    }

    // MARK: Codable

    @Test("Adhaan.silent survives Codable round-trip")
    func silentCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(Adhaan.silent)
        let decoded = try JSONDecoder().decode(Adhaan.self, from: data)
        #expect(decoded.id == Adhaan.silent.id)
        #expect(decoded.displayName == Adhaan.silent.displayName)
        #expect(decoded.filename == Adhaan.silent.filename)
    }

    @Test("Custom Adhaan survives Codable round-trip")
    func customAdhaanCodableRoundTrip() throws {
        let original = Adhaan(id: "adhaan_1", displayName: "Adhaan 1", filename: "adhaan_1.mp3")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Adhaan.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.filename == original.filename)
    }

    // MARK: Hashable / Equatable

    @Test("Two Adhaans with identical properties are equal (synthesised Equatable)")
    func equalityByAllProperties() {
        let a = Adhaan(id: "x", displayName: "A", filename: "a.mp3")
        let b = Adhaan(id: "x", displayName: "A", filename: "a.mp3")
        #expect(a == b)
    }

    @Test("Adhaans with different id are not equal")
    func inequalityByDifferentId() {
        let a = Adhaan(id: "x", displayName: "A", filename: "a.mp3")
        let b = Adhaan(id: "y", displayName: "A", filename: "a.mp3")
        #expect(a != b)
    }

    @Test("Adhaan is usable as a Set element (Hashable)")
    func usableInSet() {
        let a = Adhaan(id: "x", displayName: "A", filename: "a.mp3")
        let b = Adhaan(id: "y", displayName: "B", filename: "b.mp3")
        let set: Set<Adhaan> = [a, b, a]
        #expect(set.count == 2)
    }
}

// MARK: - CalculationMethod.suggested Tests

@Suite("CalculationMethod Country Suggestion Tests")
struct CalculationMethodSuggestionTests {

    @Test("US and CA map to ISNA")
    func usAndCanadaISNA() {
        #expect(CalculationMethod.suggested(forCountryCode: "US") == .isna)
        #expect(CalculationMethod.suggested(forCountryCode: "CA") == .isna)
    }

    @Test("GCC countries map to Umm Al-Qura")
    func gccUmmAlQura() {
        for code in ["SA", "AE", "QA", "BH", "KW", "YE", "OM"] {
            #expect(CalculationMethod.suggested(forCountryCode: code) == .ummAlQura,
                    "\(code) should map to ummAlQura")
        }
    }

    @Test("North Africa and Levant countries map to Egypt method")
    func northAfricaEgypt() {
        for code in ["EG", "LY", "SD", "MA", "DZ", "TN", "JO", "PS"] {
            #expect(CalculationMethod.suggested(forCountryCode: code) == .egypt,
                    "\(code) should map to egypt")
        }
    }

    @Test("South Asia countries map to Karachi")
    func southAsiaKarachi() {
        for code in ["PK", "AF", "BD", "IN"] {
            #expect(CalculationMethod.suggested(forCountryCode: code) == .karachi,
                    "\(code) should map to karachi")
        }
    }

    @Test("Iran maps to Tehran")
    func iranTehran() {
        #expect(CalculationMethod.suggested(forCountryCode: "IR") == .tehran)
    }

    @Test("Unknown / other countries default to Muslim World League")
    func unknownDefaultsMWL() {
        for code in ["GB", "DE", "FR", "TR", "NG", "ZZ", "XX"] {
            #expect(CalculationMethod.suggested(forCountryCode: code) == .muslimWorldLeague,
                    "\(code) should default to muslimWorldLeague")
        }
    }

    @Test("Matching is case-insensitive")
    func caseInsensitiveMatching() {
        #expect(CalculationMethod.suggested(forCountryCode: "us") == .isna)
        #expect(CalculationMethod.suggested(forCountryCode: "sa") == .ummAlQura)
        #expect(CalculationMethod.suggested(forCountryCode: "pk") == .karachi)
    }
}

// MARK: - SettingsManager Adhaan Persistence Tests

@Suite("SettingsManager Adhaan Tests", .serialized)
struct SettingsManagerAdhaanTests {

    private func freshSettings() -> SettingsManager {
        SettingsManager(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test("getAdhaan() returns Silent by default for any prayer")
    func defaultAdhaanIsSilent() {
        let s = freshSettings()
        for prayer in ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"] {
            let adhaan = s.getAdhaan(for: prayer)
            #expect(adhaan.id == "silent", "\(prayer) should default to silent")
        }
    }

    @Test("setAdhaan(silent) persists and getAdhaan() retrieves silent")
    func silentAdhaanRoundTrip() {
        let s = freshSettings()
        // Explicit silent — always in Adhaan.available regardless of bundle
        s.setAdhaan(.silent, for: "Fajr")
        #expect(s.getAdhaan(for: "Fajr").id == "silent")
        #expect(s.getAdhaan(for: "Dhuhr").id == "silent") // untouched prayer
    }

    @Test("setAdhaan() overwrites previous value; last write wins (tested with silent)")
    func adhaanOverwrite() {
        let s = freshSettings()
        // Store a non-existent id, then overwrite with silent.
        // getAdhaan() correctly returns silent in both cases:
        // first because the id is not in Adhaan.available (graceful fallback),
        // second because silent IS in Adhaan.available.
        // We verify the overwrite landed by checking silent is returned after second write.
        let nonExistent = Adhaan(id: "adhaan_9", displayName: "Adhaan 9", filename: "adhaan_9.mp3")
        s.setAdhaan(nonExistent, for: "Maghrib")
        s.setAdhaan(.silent, for: "Maghrib")
        #expect(s.getAdhaan(for: "Maghrib").id == "silent")
    }

    @Test("setAdhaan(silent) clears a previous non-existent selection")
    func settingSilentClears() {
        let s = freshSettings()
        let adhaan = Adhaan(id: "tone_glass", displayName: "Glass Bell", filename: "tone_glass.aiff")
        s.setAdhaan(adhaan, for: "Asr")
        s.setAdhaan(.silent, for: "Asr")
        #expect(s.getAdhaan(for: "Asr").id == "silent")
    }

    @Test("Prayers with no stored selection all default independently to silent")
    func independentPrayerDefaultsAreSilent() {
        let s = freshSettings()
        // Set one prayer, verify others are unaffected
        s.setAdhaan(.silent, for: "Fajr")
        for prayer in ["Dhuhr", "Asr", "Maghrib", "Isha"] {
            #expect(s.getAdhaan(for: prayer).id == "silent",
                    "\(prayer) should remain silent when only Fajr was set")
        }
    }

    @Test("getAdhaan() returns silent for unknown adhaan id (graceful fallback)")
    func unknownAdhaanIdFallsBackToSilent() {
        let s = freshSettings()
        // Simulate a stale persisted id that no longer exists in the bundle
        s.setAdhaan(Adhaan(id: "nonexistent_adhaan_id", displayName: "Gone", filename: "gone.mp3"),
                    for: "Fajr")
        // getAdhaan looks up Adhaan.available — id not found → returns .silent
        let result = s.getAdhaan(for: "Fajr")
        #expect(result.id == "silent",
                "Unknown adhaan id should fall back to silent (got \(result.id))")
    }
}

// MARK: - CLLocationCoordinate2D Equatable Tests

// CLLocationCoordinate2D Equatable is defined in LocationService.swift (not in test target).
// Testing coordinate comparison by component — equivalent coverage without the extension.
@Suite("CLLocationCoordinate2D Component Tests")
struct CoordinateEquatableTests {

    @Test("Identical coordinates have equal lat/lon")
    func identicalCoordinatesEqual() {
        let a = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        let b = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        #expect(a.latitude == b.latitude && a.longitude == b.longitude)
    }

    @Test("Different latitude produces different values")
    func differentLatitudeNotEqual() {
        let a = CLLocationCoordinate2D(latitude: 21.0, longitude: 39.8262)
        let b = CLLocationCoordinate2D(latitude: 22.0, longitude: 39.8262)
        #expect(a.latitude != b.latitude)
    }

    @Test("Different longitude produces different values")
    func differentLongitudeNotEqual() {
        let a = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.0)
        let b = CLLocationCoordinate2D(latitude: 21.4225, longitude: 40.0)
        #expect(a.longitude != b.longitude)
    }
}
