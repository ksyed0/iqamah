import Foundation

// MARK: - Moon phase

/// Synodic phase fraction: 0.0 = new moon, 0.5 = full moon, 1.0 = new moon again.
/// Uses NewMoon.previous(before:) as the reference epoch.
public func moonPhase(for date: Date) -> Double {
    let previousNewMoon = NewMoon.previous(before: date)
    let elapsed = date.timeIntervalSince(previousNewMoon)
    let synodicMonth = 29.530588853 * 86400.0
    return (elapsed / synodicMonth).truncatingRemainder(dividingBy: 1.0)
}

// MARK: - Hijri date string

/// Returns a formatted Hijri date string, e.g. "9 Dhu al-Hijjah 1447".
/// The `offset` parameter shifts the displayed day without affecting astronomy —
/// matches SettingsManager.hijriDayOffset.
public func hijriDateString(for date: Date, offset: Int = 0) -> String {
    let cal = Calendar(identifier: .islamicUmmAlQura)
    var comps = cal.dateComponents([.day, .month, .year], from: date)
    comps.day = (comps.day ?? 1) + offset

    let monthNames = [
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah",
    ]
    let monthIndex = (comps.month ?? 1) - 1
    let monthName = monthIndex >= 0 && monthIndex < 12 ? monthNames[monthIndex] : ""
    return "\(comps.day ?? 1) \(monthName) \(comps.year ?? 1446)"
}
