import Foundation

/// A planned notification — fire date plus the body text the scheduler should attach.
public struct FastingNotificationPlan: Equatable, Sendable {
    public let fireDate: Date
    public let title: String
    public let body: String
    public let identifier: String
}

/// Pure helpers for computing notification fire dates for Fasting Mode reminders.
/// Per-platform schedulers wrap these with UNUserNotificationCenter calls.
public enum FastingNotificationPlanner {

    /// When should the Suhoor reminder fire for a given Fajr time?
    public static func suhoorFireDate(fajr: Date, settings: FastingModeSettings) -> Date {
        fajr.addingTimeInterval(-Double(settings.suhoorLeadMinutes) * 60)
    }

    /// When should the Iftar reminder fire for a given Maghrib time?
    public static func iftarFireDate(maghrib: Date, settings: FastingModeSettings) -> Date {
        maghrib.addingTimeInterval(-Double(settings.iftarLeadMinutes) * 60)
    }

    /// Plan the day-before reminder for `tomorrow`. Returns nil when the reminder should be skipped:
    /// - dayBeforeEnabled is false
    /// - notificationsEnabled is false
    /// - tomorrow has a prohibition
    /// - tomorrow is Ramadan day 2–30 (day 1 is included; days 2–30 are skipped)
    /// - tomorrow is inactive (no fasting day to remind about)
    public static func dayBefore(
        tomorrow: Date,
        tomorrowState: FastingDayState,
        settings: FastingModeSettings,
        hijriCalendar: Calendar,
        timezone: TimeZone
    ) -> FastingNotificationPlan? {
        guard settings.notificationsEnabled, settings.dayBeforeEnabled else { return nil }
        guard tomorrowState.prohibition == nil else { return nil }
        guard tomorrowState.isActive else { return nil }

        var hCal = hijriCalendar
        hCal.timeZone = timezone
        let hijriMonth = hCal.component(.month, from: tomorrow)
        let hijriDay = hCal.component(.day, from: tomorrow)
        if hijriMonth == 9, hijriDay >= 2, hijriDay <= 30 {
            return nil
        }

        var gregCal = Calendar(identifier: .gregorian)
        gregCal.timeZone = timezone
        guard let dayBeforeDate = gregCal.date(byAdding: .day, value: -1, to: tomorrow) else { return nil }
        var components = gregCal.dateComponents([.year, .month, .day], from: dayBeforeDate)
        components.hour = settings.dayBeforeHour
        components.minute = settings.dayBeforeMinute
        guard let fireDate = gregCal.date(from: components) else { return nil }

        let isRamadanDayOne = (hijriMonth == 9 && hijriDay == 1)
        let title: String
        let body: String
        if isRamadanDayOne {
            title = "🌙 Ramadan begins tomorrow"
            body = "First Suhoor begins tonight"
        } else {
            title = "🕗 Fasting tomorrow"
            body = "Suhoor preparations begin tonight"
        }

        let identifier = identifier(for: tomorrow, kind: "daybefore", timezone: timezone)
        return FastingNotificationPlan(
            fireDate: fireDate, title: title, body: body, identifier: identifier
        )
    }

    /// Stable per-day identifier: `fastingmode.<kind>.yyyy-MM-dd`
    public static func identifier(for date: Date, kind: String, timezone: TimeZone) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = timezone
        return "fastingmode.\(kind).\(fmt.string(from: date))"
    }
}
