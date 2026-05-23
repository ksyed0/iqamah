import Foundation

/// Pure-functional engine that decides "is today a fasting day?".
/// Called at every render site; no caching, no I/O.
public enum FastingModeEngine {

    /// Evaluate today's Fasting Mode state against the user's settings.
    /// - Parameters:
    ///   - date: The day to evaluate (typically `Date()`).
    ///   - settings: User Fasting Mode preferences.
    ///   - calculationMethod: Affects muharramFast date set and Shia-gated trigger suppression.
    ///   - hijriCalendar: Calendar(identifier: .islamicUmmAlQura) or similar.
    ///   - timezone: User's active timezone (settings.activeTimezoneIdentifier).
    /// - Returns: FastingDayState describing today.
    public static func evaluate(
        for date: Date,
        settings: FastingModeSettings,
        calculationMethod: CalculationMethod,
        hijriCalendar: Calendar,
        timezone: TimeZone
    ) -> FastingDayState {
        guard settings.enabled else {
            return .inactive(date: date)
        }

        var gregCal = Calendar(identifier: .gregorian)
        gregCal.timeZone = timezone
        var hCal = hijriCalendar
        hCal.timeZone = timezone

        // (Future tasks: prohibition filter runs here before triggers.)

        if settings.autoRamadan {
            let hijriMonth = hCal.component(.month, from: date)
            if hijriMonth == 9 {
                return FastingDayState(
                    isActive: true,
                    trigger: .autoRamadan,
                    prohibition: nil,
                    date: date
                )
            }
        }

        if !settings.weeklyDays.isEmpty {
            let weekday = gregCal.component(.weekday, from: date)
            if settings.weeklyDays.contains(weekday) {
                return FastingDayState(
                    isActive: true,
                    trigger: .weeklySchedule,
                    prohibition: nil,
                    date: date
                )
            }
        }

        return .inactive(date: date)
    }
}
