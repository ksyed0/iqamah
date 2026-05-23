import Testing
import Foundation
@testable import IqamahCore

@Suite("FastingNotificationPlanner")
struct FastingNotificationPlannerTests {
    static let tz = TimeZone(identifier: "America/Toronto")!
    static let hijri = Calendar(identifier: .islamicUmmAlQura)

    static func fajrTime(hour: Int = 5, minute: Int = 12) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: hour, minute: minute))!
    }

    static func maghribTime(hour: Int = 20, minute: Int = 32) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: hour, minute: minute))!
    }

    @Test("Suhoor 30-min lead fires 30 minutes before Fajr")
    func suhoorThirtyMinLead() {
        var s = FastingModeSettings()
        s.suhoorLeadMinutes = 30
        let fajr = Self.fajrTime()
        let fire = FastingNotificationPlanner.suhoorFireDate(fajr: fajr, settings: s)
        #expect(fire == fajr.addingTimeInterval(-30 * 60))
    }

    @Test("Suhoor 120-min lead fires 2 hours before Fajr")
    func suhoorOneTwentyMinLead() {
        var s = FastingModeSettings()
        s.suhoorLeadMinutes = 120
        let fajr = Self.fajrTime()
        let fire = FastingNotificationPlanner.suhoorFireDate(fajr: fajr, settings: s)
        #expect(fire == fajr.addingTimeInterval(-120 * 60))
    }

    @Test("Iftar 15-min lead fires 15 minutes before Maghrib")
    func iftarFifteenMinLead() {
        var s = FastingModeSettings()
        s.iftarLeadMinutes = 15
        let maghrib = Self.maghribTime()
        let fire = FastingNotificationPlanner.iftarFireDate(maghrib: maghrib, settings: s)
        #expect(fire == maghrib.addingTimeInterval(-15 * 60))
    }

    @Test("Day-before fires for Ramadan day 1 — tomorrow is 1 Ramadan")
    func dayBeforeRamadanDay1Fires() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = true
        s.dayBeforeHour = 20
        s.dayBeforeMinute = 0
        s.autoRamadan = true
        var hCal = Self.hijri
        hCal.timeZone = Self.tz
        let tomorrow = hCal.date(from: DateComponents(year: 1448, month: 9, day: 1, hour: 12))!
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .autoRamadan, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: hCal,
            timezone: Self.tz
        )
        #expect(plan != nil)
    }

    @Test("Day-before skipped for Ramadan day 2")
    func dayBeforeRamadanDay2Skipped() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = true
        s.autoRamadan = true
        var hCal = Self.hijri
        hCal.timeZone = Self.tz
        let tomorrow = hCal.date(from: DateComponents(year: 1448, month: 9, day: 2, hour: 12))!
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .autoRamadan, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: hCal,
            timezone: Self.tz
        )
        #expect(plan == nil)
    }

    @Test("Day-before fires for an active non-Ramadan day")
    func dayBeforeActiveNonRamadanFires() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = true
        var hCal = Self.hijri
        hCal.timeZone = Self.tz
        let tomorrow = hCal.date(from: DateComponents(year: 1448, month: 6, day: 15, hour: 12))!
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .weeklySchedule, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: hCal,
            timezone: Self.tz
        )
        #expect(plan != nil)
    }

    @Test("Day-before skipped when dayBeforeEnabled is false")
    func dayBeforeDisabledSkipped() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = false
        let tomorrow = Self.fajrTime()
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .weeklySchedule, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(plan == nil)
    }

    @Test("Day-before skipped when tomorrow is hard-prohibited")
    func dayBeforeProhibitionSkipped() {
        var s = FastingModeSettings()
        s.dayBeforeEnabled = true
        let tomorrow = Self.fajrTime()
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: false, trigger: nil, prohibition: .eidAlFitr, date: tomorrow),
            settings: s,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(plan == nil)
    }

    @Test("Day-before skipped when notificationsEnabled is false")
    func dayBeforeNotificationsDisabledSkipped() {
        var s = FastingModeSettings()
        s.notificationsEnabled = false
        s.dayBeforeEnabled = true
        let tomorrow = Self.fajrTime()
        let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow,
            tomorrowState: FastingDayState(isActive: true, trigger: .weeklySchedule, prohibition: nil, date: tomorrow),
            settings: s,
            hijriCalendar: Self.hijri,
            timezone: Self.tz
        )
        #expect(plan == nil)
    }
}
