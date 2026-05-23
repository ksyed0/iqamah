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
