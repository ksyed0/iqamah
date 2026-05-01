import XCTest
import Foundation
import CoreLocation
@testable import Iqamah

// MARK: - Prayer Calculator Tests

final class PrayerCalculatorTests: XCTestCase {
    
    func testNewYorkPrayerTimes() throws {
        // Test case: New York, NY on June 21, 2024 (summer solstice)
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let timezone = TimeZone(identifier: "America/New_York")!
        let calculator = PrayerCalculator(
            coordinate: coordinate,
            timezone: timezone,
            method: .isna,
            asrMethod: .standard
        )
        
        // June 21, 2024 at noon
        let dateComponents = DateComponents(year: 2024, month: 6, day: 21, hour: 12)
        let date = Calendar.current.date(from: dateComponents)!
        
        let prayerTimes = calculator.calculate(for: date)
        
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "HH:mm"
        
        // Verify all times are calculated (not nil)
        XCTAssertNotEqual(prayerTimes.fajr, Date.distantPast)
        XCTAssertNotEqual(prayerTimes.sunrise, Date.distantPast)
        XCTAssertNotEqual(prayerTimes.dhuhr, Date.distantPast)
        XCTAssertNotEqual(prayerTimes.asr, Date.distantPast)
        XCTAssertNotEqual(prayerTimes.maghrib, Date.distantPast)
        XCTAssertNotEqual(prayerTimes.isha, Date.distantPast)
        
        // Verify prayer times are in chronological order
        XCTAssertLessThan(prayerTimes.fajr, prayerTimes.sunrise)
        XCTAssertLessThan(prayerTimes.sunrise, prayerTimes.dhuhr)
        XCTAssertLessThan(prayerTimes.dhuhr, prayerTimes.asr)
        XCTAssertLessThan(prayerTimes.asr, prayerTimes.maghrib)
        XCTAssertLessThan(prayerTimes.maghrib, prayerTimes.isha)
    }
    
    func testMakkahPrayerTimes() throws {
        // Test case: Makkah (Ka'bah coordinates)
        let coordinate = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        let timezone = TimeZone(identifier: "Asia/Riyadh")!
        let calculator = PrayerCalculator(
            coordinate: coordinate,
            timezone: timezone,
            method: .ummAlQura,
            asrMethod: .standard
        )
        
        let dateComponents = DateComponents(year: 2024, month: 1, day: 15, hour: 12)
        let date = Calendar.current.date(from: dateComponents)!
        
        let prayerTimes = calculator.calculate(for: date)
        
        // Verify chronological order
        XCTAssertLessThan(prayerTimes.fajr, prayerTimes.sunrise)
        XCTAssertLessThan(prayerTimes.sunrise, prayerTimes.dhuhr)
        XCTAssertLessThan(prayerTimes.dhuhr, prayerTimes.asr)
        XCTAssertLessThan(prayerTimes.asr, prayerTimes.maghrib)
        XCTAssertLessThan(prayerTimes.maghrib, prayerTimes.isha)
        
        // Verify Umm Al-Qura uses 90-minute interval for Isha
        let calendar = Calendar.current
        let minutesBetween = calendar.dateComponents([.minute], from: prayerTimes.maghrib, to: prayerTimes.isha).minute ?? 0
        XCTAssertEqual(minutesBetween, 90, "Umm Al-Qura should use 90-minute interval for Isha")
    }
    
    func testAsrMethodDifference() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let timezone = TimeZone(identifier: "America/New_York")!
        
        let standardCalculator = PrayerCalculator(
            coordinate: coordinate,
            timezone: timezone,
            method: .isna,
            asrMethod: .standard
        )
        
        let hanafiCalculator = PrayerCalculator(
            coordinate: coordinate,
            timezone: timezone,
            method: .isna,
            asrMethod: .hanafi
        )
        
        let dateComponents = DateComponents(year: 2024, month: 6, day: 21, hour: 12)
        let date = Calendar.current.date(from: dateComponents)!
        
        let standardTimes = standardCalculator.calculate(for: date)
        let hanafiTimes = hanafiCalculator.calculate(for: date)
        
        // Hanafi Asr should be later than Standard Asr
        XCTAssertGreaterThan(hanafiTimes.asr, standardTimes.asr, "Hanafi Asr should be later than Standard Asr")
        
        // All other prayer times should be identical
        XCTAssertEqual(standardTimes.fajr, hanafiTimes.fajr)
        XCTAssertEqual(standardTimes.dhuhr, hanafiTimes.dhuhr)
        XCTAssertEqual(standardTimes.maghrib, hanafiTimes.maghrib)
        XCTAssertEqual(standardTimes.isha, hanafiTimes.isha)
    }
    
    func testAllCalculationMethods() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let timezone = TimeZone(identifier: "America/New_York")!
        
        let dateComponents = DateComponents(year: 2024, month: 6, day: 21, hour: 12)
        let date = Calendar.current.date(from: dateComponents)!
        
        let methods: [CalculationMethod] = [.muslimWorldLeague, .isna, .egypt, .ummAlQura, .karachi, .tehran]
        
        for method in methods {
            let calculator = PrayerCalculator(
                coordinate: coordinate,
                timezone: timezone,
                method: method,
                asrMethod: .standard
            )
            
            let prayerTimes = calculator.calculate(for: date)
            
            // Verify chronological order for each method
            XCTAssertLessThan(prayerTimes.fajr, prayerTimes.sunrise, "Fajr before Sunrise for \(method.displayName)")
            XCTAssertLessThan(prayerTimes.sunrise, prayerTimes.dhuhr, "Sunrise before Dhuhr for \(method.displayName)")
            XCTAssertLessThan(prayerTimes.dhuhr, prayerTimes.asr, "Dhuhr before Asr for \(method.displayName)")
            XCTAssertLessThan(prayerTimes.asr, prayerTimes.maghrib, "Asr before Maghrib for \(method.displayName)")
            XCTAssertLessThan(prayerTimes.maghrib, prayerTimes.isha, "Maghrib before Isha for \(method.displayName)")
        }
    }
    
    func testDateBoundaryRecalculation() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let timezone = TimeZone(identifier: "America/New_York")!
        let calculator = PrayerCalculator(
            coordinate: coordinate,
            timezone: timezone,
            method: .isna,
            asrMethod: .standard
        )
        
        // Calculate for two different dates
        let date1Components = DateComponents(year: 2024, month: 1, day: 1, hour: 12)
        let date1 = Calendar.current.date(from: date1Components)!
        
        let date2Components = DateComponents(year: 2024, month: 7, day: 1, hour: 12)
        let date2 = Calendar.current.date(from: date2Components)!
        
        let times1 = calculator.calculate(for: date1)
        let times2 = calculator.calculate(for: date2)
        
        // Prayer times should be different between winter and summer
        XCTAssertNotEqual(times1.fajr, times2.fajr, "Winter and summer Fajr times should differ")
        XCTAssertNotEqual(times1.dhuhr, times2.dhuhr, "Winter and summer Dhuhr times should differ")
    }
}

// MARK: - Hijri Date Tests

final class HijriDateTests: XCTestCase {
    
    func testHijriConversion() throws {
        let dateComponents = DateComponents(year: 2024, month: 3, day: 12, hour: 12)
        let date = Calendar.current.date(from: dateComponents)!
        
        let hijri = date.hijriDate()
        
        // Verify all components are present
        XCTAssertTrue(hijri.day > 0 && hijri.day <= 30)
        XCTAssertTrue(hijri.month > 0 && hijri.month <= 12)
        XCTAssertTrue(hijri.year > 1400) // Should be in the 1400s Hijri
        XCTAssertFalse(hijri.monthName.isEmpty)
    }
    
    func testHijriMonthNames() throws {
        let expectedMonths = [
            "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
            "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
            "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
        ]
        
        // Test that each month produces expected name
        for (monthIndex, expectedName) in expectedMonths.enumerated() {
            var hijriComponents = DateComponents()
            hijriComponents.calendar = Calendar(identifier: .islamicUmmAlQura)
            hijriComponents.year = 1445
            hijriComponents.month = monthIndex + 1
            hijriComponents.day = 15
            
            guard let hijriDate = hijriComponents.date else {
                XCTFail("Failed to create Hijri date for month \(monthIndex + 1)")
                continue
            }
            
            let convertedHijri = hijriDate.hijriDate()
            XCTAssertEqual(convertedHijri.monthName, expectedName, "Month name should be \(expectedName)")
        }
    }
    
    func testFormattedHijriDate() throws {
        let dateComponents = DateComponents(year: 2024, month: 3, day: 12, hour: 12)
        let date = Calendar.current.date(from: dateComponents)!
        
        let formatted = date.formattedHijriDate()
        
        // Should end with " AH"
        XCTAssertTrue(formatted.hasSuffix(" AH"), "Formatted Hijri date should end with ' AH'")
        
        // Should contain at least day, month name, and year
        XCTAssertGreaterThanOrEqual(formatted.components(separatedBy: " ").count, 4, "Should have day, month name, year, and AH")
    }
    
    func testFormattedGregorianDate() throws {
        let dateComponents = DateComponents(year: 2024, month: 3, day: 12, hour: 12)
        let date = Calendar.current.date(from: dateComponents)!
        
        let formatted = date.formattedGregorianDate()
        
        // Should contain year
        XCTAssertTrue(formatted.contains("2024"), "Formatted Gregorian date should contain year")
        
        // Should contain month and day
        XCTAssertFalse(formatted.isEmpty, "Formatted date should not be empty")
    }
}

// MARK: - Qibla Calculation Tests

final class QiblahCalculationTests: XCTestCase {
    
    func testQiblahFromNewYork() throws {
        let userLat = 40.7128
        let userLon = -74.0060
        let kaabahLat = 21.4225
        let kaabahLon = 39.8262
        
        let bearing = calculateQiblahBearing(fromLat: userLat, fromLon: userLon, toKaabahLat: kaabahLat, toKaabahLon: kaabahLon)
        
        // From New York, Qibla should be roughly northeast (between 0° and 90°)
        XCTAssertTrue(bearing >= 0 && bearing < 360, "Bearing should be 0-360°")
        XCTAssertTrue(bearing > 30 && bearing < 90, "From New York, Qibla should be northeast")
    }
    
    func testQiblahFromLondon() throws {
        let userLat = 51.5074
        let userLon = -0.1278
        let kaabahLat = 21.4225
        let kaabahLon = 39.8262
        
        let bearing = calculateQiblahBearing(fromLat: userLat, fromLon: userLon, toKaabahLat: kaabahLat, toKaabahLon: kaabahLon)
        
        // From London, Qibla should be roughly southeast (between 90° and 180°)
        XCTAssertTrue(bearing >= 0 && bearing < 360, "Bearing should be 0-360°")
        XCTAssertTrue(bearing > 90 && bearing < 150, "From London, Qibla should be southeast")
    }
    
    func testQiblahFromMakkah() throws {
        let kaabahLat = 21.4225
        let kaabahLon = 39.8262
        
        // Very close to Ka'bah
        let bearing = calculateQiblahBearing(fromLat: kaabahLat, fromLon: kaabahLon, toKaabahLat: kaabahLat, toKaabahLon: kaabahLon)
        
        // From Ka'bah to itself should be very small or 0
        XCTAssertTrue(bearing >= 0 && bearing < 360, "Bearing should be 0-360°")
    }
    
    func testCardinalDirections() throws {
        let testCases: [(bearing: Double, expected: String)] = [
            (0, "N"),
            (45, "NE"),
            (90, "E"),
            (135, "SE"),
            (180, "S"),
            (225, "SW"),
            (270, "W"),
            (315, "NW"),
            (359, "N")
        ]
        
        for testCase in testCases {
            let direction = cardinalDirectionFromBearing(testCase.bearing)
            XCTAssertEqual(direction, testCase.expected, "\(testCase.bearing)° should be \(testCase.expected), got \(direction)")
        }
    }
    
    // Helper functions matching QiblahView logic
    private func calculateQiblahBearing(fromLat: Double, fromLon: Double, toKaabahLat: Double, toKaabahLon: Double) -> Double {
        let lat1 = fromLat * .pi / 180
        let lat2 = toKaabahLat * .pi / 180
        let deltaLon = (toKaabahLon - fromLon) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private func cardinalDirectionFromBearing(_ bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((bearing + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return directions[index]
    }
}

// MARK: - Settings Manager Tests

final class SettingsManagerTests: XCTestCase {
    
    func testCityPersistence() throws {
        let settings = SettingsManager.shared
        
        let testCity = City(
            name: "New York",
            countryCode: "US",
            latitude: 40.7128,
            longitude: -74.0060,
            timezone: "America/New_York"
        )
        
        // Save city
        settings.saveCity(testCity)
        
        // Load city
        let loadedCity = settings.loadCity()
        
        XCTAssertNotNil(loadedCity, "Should load saved city")
        XCTAssertEqual(loadedCity?.name, testCity.name)
        XCTAssertEqual(loadedCity?.latitude, testCity.latitude)
        XCTAssertEqual(loadedCity?.longitude, testCity.longitude)
        XCTAssertEqual(loadedCity?.timezone, testCity.timezone)
    }
    
    func testCalculationMethodPersistence() throws {
        let settings = SettingsManager.shared
        
        // Save calculation method
        settings.calculationMethod = .isna
        
        // Verify it persists
        XCTAssertEqual(settings.calculationMethod, .isna)
        
        // Change and verify
        settings.calculationMethod = .ummAlQura
        XCTAssertEqual(settings.calculationMethod, .ummAlQura)
    }
    
    func testAsrMethodPersistence() throws {
        let settings = SettingsManager.shared
        
        // Save Asr method
        settings.asrMethod = .hanafi
        
        // Verify it persists
        XCTAssertEqual(settings.asrMethod, .hanafi)
        
        // Change and verify
        settings.asrMethod = .standard
        XCTAssertEqual(settings.asrMethod, .standard)
    }
    
    func testPrayerAdjustments() throws {
        let settings = SettingsManager.shared
        
        // Save adjustments
        settings.setAdjustment(5, for: "Fajr")
        settings.setAdjustment(-3, for: "Isha")
        
        // Load adjustments
        let fajrAdjustment = settings.getAdjustment(for: "Fajr")
        let ishaAdjustment = settings.getAdjustment(for: "Isha")
        let dhuhrAdjustment = settings.getAdjustment(for: "Dhuhr")
        
        XCTAssertEqual(fajrAdjustment, 5, "Fajr adjustment should be +5")
        XCTAssertEqual(ishaAdjustment, -3, "Isha adjustment should be -3")
        XCTAssertEqual(dhuhrAdjustment, 0, "Dhuhr adjustment should default to 0")
    }
    
    func testCompleteSetup() throws {
        let settings = SettingsManager.shared
        
        let testCity = City(
            name: "London",
            countryCode: "GB",
            latitude: 51.5074,
            longitude: -0.1278,
            timezone: "Europe/London"
        )
        
        // Mark as not completed
        settings.hasCompletedSetup = false
        XCTAssertFalse(settings.hasCompletedSetup)
        
        // Complete setup
        settings.completeSetup(city: testCity, calculationMethod: .muslimWorldLeague, asrMethod: .standard)
        
        // Verify all settings saved
        XCTAssertTrue(settings.hasCompletedSetup)
        XCTAssertEqual(settings.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(settings.asrMethod, .standard)
        
        let loadedCity = settings.loadCity()
        XCTAssertEqual(loadedCity?.name, testCity.name)
    }
    
    func testResetSettings() throws {
        let settings = SettingsManager.shared
        
        let testCity = City(
            name: "Toronto",
            countryCode: "CA",
            latitude: 43.65107,
            longitude: -79.347015,
            timezone: "America/Toronto"
        )
        
        // Setup
        settings.completeSetup(city: testCity, calculationMethod: .isna, asrMethod: .hanafi)
        XCTAssertTrue(settings.hasCompletedSetup)
        
        // Reset
        settings.resetSettings()
        
        // Verify reset
        XCTAssertFalse(settings.hasCompletedSetup)
        
        let loadedCity = settings.loadCity()
        XCTAssertNil(loadedCity, "City should be cleared after reset")
    }
}

// MARK: - Cities Database Tests

final class CitiesDatabaseTests: XCTestCase {
    
    func testLoadDatabase() throws {
        let database = CitiesLoader.shared.load()
        
        XCTAssertNotNil(database, "Cities database should load")
        XCTAssertGreaterThan(database!.countries.count, 0, "Should have countries")
        XCTAssertGreaterThan(database!.cities.count, 0, "Should have cities")
    }
    
    func testFindCountry() throws {
        guard let database = CitiesLoader.shared.load() else {
            XCTFail("Failed to load cities database")
            return
        }
        
        let usa = database.country(forCode: "US")
        XCTAssertNotNil(usa, "Should find USA")
        XCTAssertNotNil(usa?.name, "USA should have a name")
    }
    
    func testCitiesByCountry() throws {
        guard let database = CitiesLoader.shared.load() else {
            XCTFail("Failed to load cities database")
            return
        }
        
        let usCities = database.cities(forCountryCode: "US")
        XCTAssertGreaterThan(usCities.count, 0, "USA should have cities")
        
        // Verify cities are sorted
        for i in 0..<(usCities.count - 1) {
            XCTAssertLessThanOrEqual(usCities[i].name, usCities[i + 1].name, "Cities should be sorted alphabetically")
        }
    }
    
    func testClosestCity() throws {
        guard let database = CitiesLoader.shared.load() else {
            XCTFail("Failed to load cities database")
            return
        }
        
        // New York coordinates
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let closestCity = database.closestCity(to: coordinate)
        
        XCTAssertNotNil(closestCity, "Should find closest city")
        
        // The closest city should be relatively close (within ~500km for major cities)
        if let city = closestCity {
            let distance = city.distance(from: coordinate)
            XCTAssertLessThan(distance, 500000, "Closest city should be within 500km (got \(distance / 1000)km)")
        }
    }
    
    func testCityCoordinate() throws {
        let city = City(
            name: "Makkah",
            countryCode: "SA",
            latitude: 21.4225,
            longitude: 39.8262,
            timezone: "Asia/Riyadh"
        )
        
        let coordinate = city.coordinate
        XCTAssertEqual(coordinate.latitude, city.latitude)
        XCTAssertEqual(coordinate.longitude, city.longitude)
    }
    
    func testCityDistance() throws {
        let newYork = City(
            name: "New York",
            countryCode: "US",
            latitude: 40.7128,
            longitude: -74.0060,
            timezone: "America/New_York"
        )
        
        let london = City(
            name: "London",
            countryCode: "GB",
            latitude: 51.5074,
            longitude: -0.1278,
            timezone: "Europe/London"
        )
        
        let londonCoord = CLLocationCoordinate2D(latitude: london.latitude, longitude: london.longitude)
        let distance = newYork.distance(from: londonCoord)
        
        // Distance between New York and London is approximately 5,570 km
        XCTAssertGreaterThan(distance, 5000000, "Distance should be > 5000km")
        XCTAssertLessThan(distance, 6000000, "Distance should be < 6000km")
    }
}

// MARK: - Calculation Method Tests

final class CalculationMethodConfigTests: XCTestCase {
    
    func testDisplayNames() throws {
        for method in CalculationMethod.allCases {
            XCTAssertFalse(method.displayName.isEmpty, "\(method.rawValue) should have display name")
        }
    }
    
    func testFajrAngles() throws {
        let expectedAngles: [CalculationMethod: Double] = [
            .muslimWorldLeague: 18.0,
            .isna: 15.0,
            .egypt: 19.5,
            .ummAlQura: 18.5,
            .karachi: 18.0,
            .tehran: 17.7
        ]
        
        for (method, expectedAngle) in expectedAngles {
            XCTAssertEqual(method.fajrAngle, expectedAngle, "\(method.displayName) Fajr angle should be \(expectedAngle)°")
        }
    }
    
    func testIshaAngles() throws {
        let expectedAngles: [CalculationMethod: Double] = [
            .muslimWorldLeague: 17.0,
            .isna: 15.0,
            .egypt: 17.5,
            .ummAlQura: 0.0, // Uses interval instead
            .karachi: 18.0,
            .tehran: 14.0
        ]
        
        for (method, expectedAngle) in expectedAngles {
            XCTAssertEqual(method.ishaAngle, expectedAngle, "\(method.displayName) Isha angle should be \(expectedAngle)°")
        }
    }
    
    func testUmmAlQuraIshaInterval() throws {
        XCTAssertEqual(CalculationMethod.ummAlQura.ishaInterval, 90, "Umm Al-Qura should use 90-minute interval")
        
        // Other methods should not use interval
        XCTAssertNil(CalculationMethod.muslimWorldLeague.ishaInterval)
        XCTAssertNil(CalculationMethod.isna.ishaInterval)
    }
    
    func testTehranMaghribAngle() throws {
        XCTAssertEqual(CalculationMethod.tehran.maghribAngle, 4.5, "Tehran should use 4.5° Maghrib angle")
        
        // Other methods should not use Maghrib angle
        XCTAssertNil(CalculationMethod.muslimWorldLeague.maghribAngle)
        XCTAssertNil(CalculationMethod.isna.maghribAngle)
    }
    
    func testAsrShadowFactors() throws {
        XCTAssertEqual(AsrJuristicMethod.standard.shadowFactor, 1.0, "Standard should use 1.0 shadow factor")
        XCTAssertEqual(AsrJuristicMethod.hanafi.shadowFactor, 2.0, "Hanafi should use 2.0 shadow factor")
    }
}

// MARK: - Location Service Tests

final class LocationServiceTests: XCTestCase {
    
    func testInitialization() throws {
        let locationService = LocationService()
        
        // Should initialize with default state
        XCTAssertNil(locationService.currentLocation, "Should start with no location")
        XCTAssertFalse(locationService.isLoading, "Should not be loading initially")
        XCTAssertNil(locationService.locationError, "Should have no error initially")
    }
    
    func testAuthorizationStatus() throws {
        let locationService = LocationService()
        
        // Should have an authorization status
        let validStatuses: [CLAuthorizationStatus] = [
            .notDetermined, .restricted, .denied, .authorizedAlways, .authorizedWhenInUse
        ]
        
        XCTAssertTrue(validStatuses.contains(locationService.authorizationStatus), "Should have valid authorization status")
    }
}
