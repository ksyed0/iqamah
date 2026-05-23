import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingModeEngine — base triggers")
struct FastingModeEngineBaseTests {
    /// Convenience: build a Date at given Gregorian Y/M/D in a known timezone.
    static func date(_ y: Int, _ m: Int, _ d: Int, tz: TimeZone = TimeZone(identifier: "America/Toronto")!) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    @Test("engine is inactive when settings.enabled is false")
    func disabledReturnsInactive() {
        var s = FastingModeSettings()
        s.enabled = false
        s.autoRamadan = true
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 2, 17),
            settings: s,
            calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.isActive == false)
        #expect(result.trigger == nil)
    }

    @Test("autoRamadan fires on a Ramadan day")
    func autoRamadanFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.autoRamadan = true
        // 2026-03-01 (Toronto) resolves to Hijri 1447-9-12 under islamicUmmAlQura — i.e. Ramadan.
        let ramadanDay = Self.date(2026, 3, 1)
        // Guard against calendar-data drift — fails loud if the date assumption breaks.
        #expect(Self.hijri.component(.month, from: ramadanDay) == 9)
        let result = FastingModeEngine.evaluate(
            for: ramadanDay,
            settings: s,
            calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .autoRamadan)
    }

    @Test("autoRamadan does not fire outside Ramadan")
    func autoRamadanInactiveOutsideRamadan() {
        var s = FastingModeSettings()
        s.enabled = true
        s.autoRamadan = true
        // 2026-07-15 (Toronto) resolves to Hijri 1448-2-1 under islamicUmmAlQura — clearly not Ramadan.
        let nonRamadanDay = Self.date(2026, 7, 15)
        // Guard against calendar-data drift — fails loud if the date assumption breaks.
        #expect(Self.hijri.component(.month, from: nonRamadanDay) != 9)
        let result = FastingModeEngine.evaluate(
            for: nonRamadanDay,
            settings: s,
            calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.trigger != .autoRamadan)
        #expect(result.isActive == false)
    }

    @Test("autoRamadan does not fire when toggle is off")
    func autoRamadanOff() {
        var s = FastingModeSettings()
        s.enabled = true
        s.autoRamadan = false
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 3, 1),
            settings: s,
            calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.trigger != .autoRamadan)
    }

    @Test("weeklySchedule fires on a Monday")
    func weeklyMondayFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.weeklyDays = [2]
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 9, 14),
            settings: s,
            calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .weeklySchedule)
    }

    @Test("weeklySchedule does not fire on a Wednesday when only Mon/Thu set")
    func weeklyWednesdayInactive() {
        var s = FastingModeSettings()
        s.enabled = true
        s.weeklyDays = [2, 5]
        let result = FastingModeEngine.evaluate(
            for: Self.date(2026, 9, 16),
            settings: s,
            calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(result.isActive == false)
    }

    @Test("engine is pure — same input yields same output")
    func enginePurity() {
        var s = FastingModeSettings()
        s.enabled = true
        s.weeklyDays = [2]
        let input = Self.date(2026, 9, 14)
        let a = FastingModeEngine.evaluate(for: input, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        let b = FastingModeEngine.evaluate(for: input, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(a == b)
    }
}

@Suite("FastingModeEngine — Hijri-date triggers")
struct FastingModeEngineHijriTests {
    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    /// Build a Date for the given Hijri Y/M/D in the test timezone, at noon.
    static func hijriDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("ayyamAlBeed fires on day 13 of any Hijri month")
    func ayyamAlBeed13() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        let date = Self.hijriDate(1448, 8, 13)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.isActive == true)
        #expect(result.trigger == .ayyamAlBeed)
    }

    @Test("ayyamAlBeed fires on day 14")
    func ayyamAlBeed14() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        let date = Self.hijriDate(1448, 8, 14)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .ayyamAlBeed)
    }

    @Test("ayyamAlBeed does not fire on day 16")
    func ayyamAlBeedDay16() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        let date = Self.hijriDate(1448, 8, 16)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.isActive == false)
    }

    @Test("sixDaysShawwal fires on day 2 Shawwal")
    func sixShawwalDay2() {
        var s = FastingModeSettings()
        s.enabled = true
        s.sixDaysShawwal = true
        let date = Self.hijriDate(1448, 10, 2)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .sixDaysShawwal)
    }

    @Test("sixDaysShawwal fires on day 7 Shawwal")
    func sixShawwalDay7() {
        var s = FastingModeSettings()
        s.enabled = true
        s.sixDaysShawwal = true
        let date = Self.hijriDate(1448, 10, 7)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .sixDaysShawwal)
    }

    @Test("sixDaysShawwal does not fire on day 8 Shawwal")
    func sixShawwalDay8Inactive() {
        var s = FastingModeSettings()
        s.enabled = true
        s.sixDaysShawwal = true
        let date = Self.hijriDate(1448, 10, 8)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.isActive == false)
    }

    @Test("dayOfArafah fires on 9 Dhul-Hijjah")
    func arafahFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.dayOfArafah = true
        let date = Self.hijriDate(1448, 12, 9)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .dayOfArafah)
    }

    @Test("firstNineDhulHijjah fires on day 5")
    func firstNineDay5() {
        var s = FastingModeSettings()
        s.enabled = true
        s.firstNineDhulHijjah = true
        let date = Self.hijriDate(1448, 12, 5)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .firstNineDhulHijjah)
    }

    @Test("on 9 Dhul-Hijjah, dayOfArafah wins over firstNineDhulHijjah")
    func arafahPriorityOverFirstNine() {
        var s = FastingModeSettings()
        s.enabled = true
        s.dayOfArafah = true
        s.firstNineDhulHijjah = true
        let date = Self.hijriDate(1448, 12, 9)
        let result = FastingModeEngine.evaluate(for: date, settings: s, calculationMethod: .muslimWorldLeague, hijriCalendar: Self.hijri, timezone: Self.tz)
        #expect(result.trigger == .dayOfArafah)
    }
}

@Suite("FastingModeEngine — muharramFast tradition-adaptive")
struct FastingModeEngineMuharramTests {
    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    static func hijriDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("Sunni method: muharramFast fires on 10 Muharram (Ashura)")
    func sunniDay10() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 10)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .muharramFast)
    }

    @Test("Sunni method: muharramFast fires on 9 Muharram (Tasu'a)")
    func sunniDay9() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 9)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .isna,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .muharramFast)
    }

    @Test("Sunni method: muharramFast does NOT fire on 11 Muharram")
    func sunniDay11Inactive() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 11)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
    }

    @Test("Shia (tehran): muharramFast fires on 9 Muharram only")
    func shiaTehranDay9() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 9)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .tehran,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .muharramFast)
    }

    @Test("Shia (tehran): muharramFast does NOT fire on 10 Muharram")
    func shiaTehranDay10Inactive() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 10)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .tehran,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
    }

    @Test("Shia (jafari): muharramFast fires on 9 Muharram")
    func shiaJafariDay9() {
        var s = FastingModeSettings()
        s.enabled = true
        s.muharramFast = true
        let date = Self.hijriDate(1448, 1, 9)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .jafari,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == true)
        #expect(result.trigger == .muharramFast)
    }
}

@Suite("FastingModeEngine — Shia-gated triggers")
struct FastingModeEngineShiaGatedTests {
    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    static func hijriDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("midShaban fires for Shia method on 15 Sha'ban")
    func midShabanShiaFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.midShaban = true
        let date = Self.hijriDate(1448, 8, 15)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .tehran,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.trigger == .midShaban)
    }

    @Test("midShaban suppressed for Sunni method even when toggle is true")
    func midShabanSunniSuppressed() {
        var s = FastingModeSettings()
        s.enabled = true
        s.midShaban = true
        let date = Self.hijriDate(1448, 8, 15)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
    }

    @Test("mabath fires for Shia method on 27 Rajab")
    func mabathShiaFires() {
        var s = FastingModeSettings()
        s.enabled = true
        s.mabath = true
        let date = Self.hijriDate(1448, 7, 27)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .jafari,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.trigger == .mabath)
    }

    @Test("mabath suppressed for Sunni method")
    func mabathSunniSuppressed() {
        var s = FastingModeSettings()
        s.enabled = true
        s.mabath = true
        let date = Self.hijriDate(1448, 7, 27)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .karachi,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
    }
}

@Suite("FastingModeEngine — prohibition filter")
struct FastingModeEngineProhibitionTests {
    static let hijri = Calendar(identifier: .islamicUmmAlQura)
    static let tz = TimeZone(identifier: "America/Toronto")!

    static func hijriDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("Eid al-Fitr suppresses sixDaysShawwal trigger")
    func eidAlFitrSuppressesShawwal() {
        var s = FastingModeSettings()
        s.enabled = true
        s.sixDaysShawwal = true
        let date = Self.hijriDate(1448, 10, 1)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
        #expect(result.prohibition == .eidAlFitr)
    }

    @Test("Eid al-Adha suppresses any trigger")
    func eidAlAdhaSuppresses() {
        var s = FastingModeSettings()
        s.enabled = true
        s.dayOfArafah = true
        s.firstNineDhulHijjah = true
        s.weeklyDays = [1, 2, 3, 4, 5, 6, 7]
        let date = Self.hijriDate(1448, 12, 10)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
        #expect(result.prohibition == .eidAlAdha)
    }

    @Test("Tashriq 11 suppresses ayyamAlBeed")
    func tashriq11SuppressesAyyamAlBeed() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        let date = Self.hijriDate(1448, 12, 11)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.prohibition == .tashriq11)
    }

    @Test("Tashriq 12 suppresses any trigger")
    func tashriq12Suppresses() {
        var s = FastingModeSettings()
        s.enabled = true
        s.weeklyDays = [1, 2, 3, 4, 5, 6, 7]
        let date = Self.hijriDate(1448, 12, 12)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.prohibition == .tashriq12)
    }

    @Test("Tashriq 13 suppresses ayyamAlBeed")
    func tashriq13SuppressesAyyamAlBeed() {
        var s = FastingModeSettings()
        s.enabled = true
        s.ayyamAlBeed = true
        let date = Self.hijriDate(1448, 12, 13)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.prohibition == .tashriq13)
    }

    @Test("ordinary day with no triggers stays inactive (no prohibition)")
    func ordinaryDayInactive() {
        var s = FastingModeSettings()
        s.enabled = true
        let date = Self.hijriDate(1448, 6, 20)
        let result = FastingModeEngine.evaluate(
            for: date, settings: s, calculationMethod: .muslimWorldLeague,
            hijriCalendar: Self.hijri, timezone: Self.tz
        )
        #expect(result.isActive == false)
        #expect(result.prohibition == nil)
    }
}
