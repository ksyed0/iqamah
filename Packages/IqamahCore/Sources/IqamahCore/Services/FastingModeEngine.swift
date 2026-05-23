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

        let hijriMonth = hCal.component(.month, from: date)
        let hijriDay = hCal.component(.day, from: date)

        // Prohibition filter — always wins over any trigger.
        if hijriMonth == 10, hijriDay == 1 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .eidAlFitr, date: date)
        }
        if hijriMonth == 12, hijriDay == 10 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .eidAlAdha, date: date)
        }
        if hijriMonth == 12, hijriDay == 11 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .tashriq11, date: date)
        }
        if hijriMonth == 12, hijriDay == 12 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .tashriq12, date: date)
        }
        if hijriMonth == 12, hijriDay == 13 {
            return FastingDayState(isActive: false, trigger: nil, prohibition: .tashriq13, date: date)
        }

        // autoRamadan
        if settings.autoRamadan, hijriMonth == 9 {
            return FastingDayState(isActive: true, trigger: .autoRamadan, prohibition: nil, date: date)
        }

        // dayOfArafah — priority over firstNineDhulHijjah on day 9
        if settings.dayOfArafah, hijriMonth == 12, hijriDay == 9 {
            return FastingDayState(isActive: true, trigger: .dayOfArafah, prohibition: nil, date: date)
        }

        // firstNineDhulHijjah
        if settings.firstNineDhulHijjah, hijriMonth == 12, (1...9).contains(hijriDay) {
            return FastingDayState(isActive: true, trigger: .firstNineDhulHijjah, prohibition: nil, date: date)
        }

        // muharramFast — date set adapts to calculation method
        if settings.muharramFast, hijriMonth == 1 {
            let firesToday: Bool = if calculationMethod.isShiaMethod {
                hijriDay == 9
            } else {
                hijriDay == 9 || hijriDay == 10
            }
            if firesToday {
                return FastingDayState(isActive: true, trigger: .muharramFast, prohibition: nil, date: date)
            }
        }

        // ayyamAlBeed
        if settings.ayyamAlBeed, (13...15).contains(hijriDay) {
            return FastingDayState(isActive: true, trigger: .ayyamAlBeed, prohibition: nil, date: date)
        }

        // sixDaysShawwal
        if settings.sixDaysShawwal, hijriMonth == 10, (2...7).contains(hijriDay) {
            return FastingDayState(isActive: true, trigger: .sixDaysShawwal, prohibition: nil, date: date)
        }

        // midShaban — Shia-gated
        if settings.midShaban, calculationMethod.isShiaMethod, hijriMonth == 8, hijriDay == 15 {
            return FastingDayState(isActive: true, trigger: .midShaban, prohibition: nil, date: date)
        }

        // mabath (27 Rajab) — Shia-gated
        if settings.mabath, calculationMethod.isShiaMethod, hijriMonth == 7, hijriDay == 27 {
            return FastingDayState(isActive: true, trigger: .mabath, prohibition: nil, date: date)
        }

        // weeklySchedule
        if !settings.weeklyDays.isEmpty {
            let weekday = gregCal.component(.weekday, from: date)
            if settings.weeklyDays.contains(weekday) {
                return FastingDayState(isActive: true, trigger: .weeklySchedule, prohibition: nil, date: date)
            }
        }

        return .inactive(date: date)
    }
}
