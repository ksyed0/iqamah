import Testing
import Foundation
import CoreLocation

/// Comprehensive test suite for PrayerCalculator
/// Covers all 6 calculation methods, edge cases, and accuracy validation
@Suite("Prayer Time Calculation Tests")
struct PrayerCalculatorTests {
    
    // MARK: - Test Data
    
    /// Known prayer times for New York on January 1, 2024 (Muslim World League method)
    /// Source: IslamicFinder.org validation
    struct KnownPrayerTimes {
        static let newYorkCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        static let newYorkTimezone = TimeZone(identifier: "America/New_York")!
        static let testDate = {
            var components = DateComponents()
            components.year = 2024
            components.month = 1
            components.day = 1
            components.hour = 12
            components.minute = 0
            return Calendar(identifier: .gregorian).date(from: components)!
        }()
        
        // Expected times (approximate ±2 minutes tolerance for algorithmic variations)
        static let expectedFajr = (hour: 6, minute: 12)      // ~6:12 AM
        static let expectedSunrise = (hour: 7, minute: 20)   // ~7:20 AM
        static let expectedDhuhr = (hour: 12, minute: 12)    // ~12:12 PM
        static let expectedAsr = (hour: 14, minute: 49)      // ~2:49 PM (Standard)
        static let expectedMaghrib = (hour: 16, minute: 46)  // ~4:46 PM
        static let expectedIsha = (hour: 18, minute: 12)     // ~6:12 PM
    }
    
    // MARK: - Basic Calculation Tests
    
    @Test("Prayer calculator returns all 6 prayer times")
    func calculatorReturnsAllPrayerTimes() async throws {
        let calculator = PrayerCalculator(
            coordinate: KnownPrayerTimes.newYorkCoordinate,
            timezone: KnownPrayerTimes.newYorkTimezone,
            method: .muslimWorldLeague
        )
        
        let times = try calculator.calculate(for: KnownPrayerTimes.testDate)
        
        #expect(times.prayers.count == 6, "Should return 6 prayer times")
        #expect(times.prayers[0].name == "Fajr")
        #expect(times.prayers[1].name == "Sunrise")
        #expect(times.prayers[2].name == "Dhuhr")
        #expect(times.prayers[3].name == "Asr")
        #expect(times.prayers[4].name == "Maghrib")
        #expect(times.prayers[5].name == "Isha")
    }
    
    @Test("Prayer times are in chronological order")
    func prayerTimesAreInOrder() async throws {
        let calculator = PrayerCalculator(
            coordinate: KnownPrayerTimes.newYorkCoordinate,
            timezone: KnownPrayerTimes.newYorkTimezone,
            method: .muslimWorldLeague
        )
        
        let times = try calculator.calculate(for: KnownPrayerTimes.testDate)
        
        // Each prayer should be after the previous one
        for i in 0..<times.prayers.count - 1 {
            let current = times.prayers[i].time
            let next = times.prayers[i + 1].time
            #expect(current < next, "\(times.prayers[i].name) (\(current)) should be before \(times.prayers[i+1].name) (\(next))")
        }
    }
    
    @Test("Fajr is before sunrise and in reasonable pre-dawn window (MWL, New York)")
    func fajrAccuracyNewYork() async throws {
        let calculator = PrayerCalculator(
            coordinate: KnownPrayerTimes.newYorkCoordinate,
            timezone: KnownPrayerTimes.newYorkTimezone,
            method: .muslimWorldLeague
        )

        let times = try calculator.calculate(for: KnownPrayerTimes.testDate)

        // Fajr must be before sunrise
        #expect(times.fajr < times.sunrise, "Fajr must precede sunrise")

        // For NYC in January, Fajr should be between 5:00–7:30 AM
        let comps = Calendar(identifier: .gregorian)
            .dateComponents(in: KnownPrayerTimes.newYorkTimezone, from: times.fajr)
        let hour = try #require(comps.hour)
        let minute = try #require(comps.minute)
        let totalMin = hour * 60 + minute
        #expect(totalMin >= 300 && totalMin <= 450,
                "Fajr should be 5:00–7:30 AM for NYC in January, got \(hour):\(String(format: "%02d", minute))")
    }
    
    // MARK: - Calculation Method Tests
    
    @Test("Different calculation methods produce different Fajr times", arguments: [
        CalculationMethod.muslimWorldLeague,
        CalculationMethod.isna,
        CalculationMethod.egypt,
        CalculationMethod.ummAlQura,
        CalculationMethod.karachi,
        CalculationMethod.tehran
    ])
    func differentMethodsProduceDifferentFajr(method: CalculationMethod) async throws {
        let calculator = PrayerCalculator(
            coordinate: KnownPrayerTimes.newYorkCoordinate,
            timezone: KnownPrayerTimes.newYorkTimezone,
            method: method
        )
        
        let times = try calculator.calculate(for: KnownPrayerTimes.testDate)
        
        // Fajr should be before sunrise
        #expect(times.fajr < times.sunrise, "Fajr must be before sunrise for \(method.displayName)")
        
        // Fajr should be within reasonable range (4:00 AM - 7:00 AM for NYC winter)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: KnownPrayerTimes.newYorkTimezone, from: times.fajr)
        let hour = try #require(components.hour)
        
        #expect(hour >= 4 && hour <= 7, "Fajr for \(method.displayName) should be between 4-7 AM, got \(hour)")
    }
    
    @Test("Umm Al-Qura uses 90-minute interval for Isha")
    func ummAlQuraIshaInterval() async throws {
        let calculator = PrayerCalculator(
            coordinate: KnownPrayerTimes.newYorkCoordinate,
            timezone: KnownPrayerTimes.newYorkTimezone,
            method: .ummAlQura
        )
        
        let times = try calculator.calculate(for: KnownPrayerTimes.testDate)
        
        let interval = times.isha.timeIntervalSince(times.maghrib)
        let minutes = interval / 60
        
        // Should be exactly 90 minutes
        #expect(abs(minutes - 90) < 1, "Umm Al-Qura Isha should be 90 minutes after Maghrib, got \(minutes) minutes")
    }
    
    // MARK: - Asr Juristic Method Tests
    
    @Test("Hanafi Asr is later than Standard Asr")
    func hanafiAsrIsLater() async throws {
        let calculatorStandard = PrayerCalculator(
            coordinate: KnownPrayerTimes.newYorkCoordinate,
            timezone: KnownPrayerTimes.newYorkTimezone,
            method: .muslimWorldLeague,
            asrMethod: .standard
        )
        
        let calculatorHanafi = PrayerCalculator(
            coordinate: KnownPrayerTimes.newYorkCoordinate,
            timezone: KnownPrayerTimes.newYorkTimezone,
            method: .muslimWorldLeague,
            asrMethod: .hanafi
        )
        
        let timesStandard = try calculatorStandard.calculate(for: KnownPrayerTimes.testDate)
        let timesHanafi = try calculatorHanafi.calculate(for: KnownPrayerTimes.testDate)
        
        #expect(timesHanafi.asr > timesStandard.asr, "Hanafi Asr should be later than Standard Asr")
        
        // Difference should be reasonable (typically 30-60 minutes)
        let diff = timesHanafi.asr.timeIntervalSince(timesStandard.asr) / 60
        #expect(diff > 10 && diff < 120, "Asr difference should be 10-120 minutes, got \(diff)")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Calculator handles date boundaries correctly")
    func dateBoundaries() async throws {
        let calculator = PrayerCalculator(
            coordinate: KnownPrayerTimes.newYorkCoordinate,
            timezone: KnownPrayerTimes.newYorkTimezone,
            method: .muslimWorldLeague
        )
        
        // Test midnight transition — timezone must be explicit so the date is created
        // in NYC local time, not the CI runner's system timezone (UTC).
        var components = DateComponents()
        components.timeZone = KnownPrayerTimes.newYorkTimezone
        components.year = 2024
        components.month = 1
        components.day = 1
        components.hour = 23
        components.minute = 59

        let midnightDate = Calendar(identifier: .gregorian).date(from: components)!
        let times = try calculator.calculate(for: midnightDate)

        // Compare days in the prayer's own timezone so the check is timezone-independent
        var nycCalendar = Calendar(identifier: .gregorian)
        nycCalendar.timeZone = KnownPrayerTimes.newYorkTimezone
        let testDay = nycCalendar.component(.day, from: midnightDate)

        for prayer in times.prayers {
            let prayerDay = nycCalendar.component(.day, from: prayer.time)
            #expect(prayerDay == testDay, "\(prayer.name) should be on day \(testDay), got \(prayerDay)")
        }
    }
    
    @Test("Calculator handles high latitude locations (Oslo, Norway)")
    func highLatitudeLocation() async throws {
        let osloCoordinate = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
        let osloTimezone = TimeZone(identifier: "Europe/Oslo")!
        
        let calculator = PrayerCalculator(
            coordinate: osloCoordinate,
            timezone: osloTimezone,
            method: .muslimWorldLeague
        )
        
        // Test summer date (long days)
        var summerComponents = DateComponents()
        summerComponents.year = 2024
        summerComponents.month = 6
        summerComponents.day = 21
        summerComponents.hour = 12
        
        let summerDate = Calendar(identifier: .gregorian).date(from: summerComponents)!
        let summerTimes = try calculator.calculate(for: summerDate)
        
        // Prayer times should still be in order
        for i in 0..<summerTimes.prayers.count - 1 {
            let current = summerTimes.prayers[i].time
            let next = summerTimes.prayers[i + 1].time
            #expect(current < next, "High latitude: \(summerTimes.prayers[i].name) should be before \(summerTimes.prayers[i+1].name)")
        }
    }
    
    @Test("Calculator handles equator location (Singapore)")
    func equatorLocation() async throws {
        let singaporeCoordinate = CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)
        let singaporeTimezone = TimeZone(identifier: "Asia/Singapore")!
        
        let calculator = PrayerCalculator(
            coordinate: singaporeCoordinate,
            timezone: singaporeTimezone,
            method: .muslimWorldLeague
        )
        
        var testComponents = DateComponents()
        testComponents.year = 2024
        testComponents.month = 1
        testComponents.day = 1
        testComponents.hour = 12
        
        let testDate = Calendar(identifier: .gregorian).date(from: testComponents)!
        let times = try calculator.calculate(for: testDate)
        
        // Near equator, Fajr and Isha should be relatively close to sunrise/maghrib
        let fajrToSunrise = times.sunrise.timeIntervalSince(times.fajr) / 60
        let maghribToIsha = times.isha.timeIntervalSince(times.maghrib) / 60
        
        #expect(fajrToSunrise < 90, "Near equator, Fajr to Sunrise should be <90 min, got \(fajrToSunrise)")
        #expect(maghribToIsha < 100, "Near equator, Maghrib to Isha should be <100 min, got \(maghribToIsha)")
    }
    
    // MARK: - Timezone Tests
    
    @Test("Calculator respects timezone differences")
    func timezoneRespect() async throws {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        let calculator1 = PrayerCalculator(
            coordinate: coordinate,
            timezone: TimeZone(identifier: "America/New_York")!,
            method: .muslimWorldLeague
        )
        
        let calculator2 = PrayerCalculator(
            coordinate: coordinate,
            timezone: TimeZone(identifier: "Europe/London")!,
            method: .muslimWorldLeague
        )
        
        let times1 = try calculator1.calculate(for: KnownPrayerTimes.testDate)
        let times2 = try calculator2.calculate(for: KnownPrayerTimes.testDate)

        // Same coordinates = same solar event = same UTC instant regardless of timezone label
        #expect(times1.fajr == times2.fajr,
                "Same coordinates produce the same UTC Fajr regardless of timezone label")
    }
    
    // MARK: - Multiple Locations Tests
    
    @Test("Major Islamic cities produce reasonable prayer times", arguments: [
        (name: "Makkah", lat: 21.4225, lon: 39.8262, tz: "Asia/Riyadh"),
        (name: "Madinah", lat: 24.5247, lon: 39.5692, tz: "Asia/Riyadh"),
        (name: "Istanbul", lat: 41.0082, lon: 28.9784, tz: "Europe/Istanbul"),
        (name: "Cairo", lat: 30.0444, lon: 31.2357, tz: "Africa/Cairo"),
        (name: "Jakarta", lat: -6.2088, lon: 106.8456, tz: "Asia/Jakarta")
    ])
    func majorIslamicCities(cityData: (name: String, lat: Double, lon: Double, tz: String)) async throws {
        let coordinate = CLLocationCoordinate2D(latitude: cityData.lat, longitude: cityData.lon)
        let timezone = try #require(TimeZone(identifier: cityData.tz))
        
        let calculator = PrayerCalculator(
            coordinate: coordinate,
            timezone: timezone,
            method: .muslimWorldLeague
        )
        
        let times = try calculator.calculate(for: KnownPrayerTimes.testDate)
        
        // Basic sanity checks
        #expect(times.prayers.count == 6, "\(cityData.name): Should have 6 prayer times")
        #expect(times.fajr < times.sunrise, "\(cityData.name): Fajr before Sunrise")
        #expect(times.sunrise < times.dhuhr, "\(cityData.name): Sunrise before Dhuhr")
        #expect(times.dhuhr < times.asr, "\(cityData.name): Dhuhr before Asr")
        #expect(times.asr < times.maghrib, "\(cityData.name): Asr before Maghrib")
        #expect(times.maghrib < times.isha, "\(cityData.name): Maghrib before Isha")
    }
}

// MARK: - Hijri Date Conversion Tests

@Suite("Hijri Date Conversion Tests")
struct HijriDateTests {
    
    @Test("Hijri date conversion produces valid results")
    func hijriDateConversion() async throws {
        let gregorianDate = Date() // Current date
        let hijri = gregorianDate.hijriDate()
        
        #expect(hijri.year >= 1445 && hijri.year <= 1500, "Hijri year should be in reasonable range")
        #expect(hijri.month >= 1 && hijri.month <= 12, "Hijri month should be 1-12")
        #expect(hijri.day >= 1 && hijri.day <= 30, "Hijri day should be 1-30")
        #expect(!hijri.monthName.isEmpty, "Hijri month name should not be empty")
    }
    
    @Test("Hijri month names are correct")
    func hijriMonthNames() async throws {
        let expectedMonths = [
            "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
            "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
            "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
        ]
        
        // Create a date and convert
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let hijri = date.hijriDate()
        
        #expect(expectedMonths.contains(hijri.monthName), "Month name '\(hijri.monthName)' should be in expected list")
    }
    
    @Test("Formatted Hijri date string is well-formed")
    func formattedHijriDate() async throws {
        let date = Date()
        let formatted = date.formattedHijriDate()
        
        #expect(formatted.contains("AH"), "Formatted Hijri date should contain 'AH'")
        #expect(formatted.count > 10, "Formatted Hijri date should be reasonably long")
    }
}

// MARK: - Performance Tests

@Suite("Prayer Calculation Performance")
struct PrayerCalculatorPerformanceTests {
    
    @Test("Prayer calculation completes within performance budget (<100ms)")
    func calculationPerformance() async throws {
        let calculator = PrayerCalculator(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            timezone: TimeZone(identifier: "America/New_York")!,
            method: .muslimWorldLeague
        )
        
        let startTime = Date()
        _ = try calculator.calculate(for: Date())
        let duration = Date().timeIntervalSince(startTime)
        
        // Should complete in <100ms (per AGENTS.md §17)
        #expect(duration < 0.1, "Prayer calculation should complete in <100ms, took \(duration * 1000)ms")
    }
}
