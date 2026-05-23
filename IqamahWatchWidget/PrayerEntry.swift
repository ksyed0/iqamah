import Foundation
import WidgetKit

struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: Date
    let cityName: String
    let methodName: String
    // AC-0370: Fasting Mode state captured for this entry's `date`. Defaults
    // keep existing call sites (and TimelineTests) compiling unchanged.
    let fastingActive: Bool
    let fastingTriggerRaw: String?

    init(
        date: Date,
        nextPrayerName: String,
        nextPrayerTime: Date,
        cityName: String,
        methodName: String,
        fastingActive: Bool = false,
        fastingTriggerRaw: String? = nil
    ) {
        self.date = date
        self.nextPrayerName = nextPrayerName
        self.nextPrayerTime = nextPrayerTime
        self.cityName = cityName
        self.methodName = methodName
        self.fastingActive = fastingActive
        self.fastingTriggerRaw = fastingTriggerRaw
    }

    /// Apply FastingLabelFormatter relabel when active and within 2h.
    var displayedNextPrayerName: String {
        guard fastingActive,
              let trigger = fastingTriggerRaw, !trigger.isEmpty else {
            return nextPrayerName
        }
        let newLabel: String
        switch nextPrayerName {
        case "Fajr": newLabel = "Suhoor"
        case "Maghrib": newLabel = "Iftar"
        default: return nextPrayerName
        }
        let secondsUntil = nextPrayerTime.timeIntervalSince(date)
        guard (0 ... (2 * 60 * 60)).contains(secondsUntil) else { return nextPrayerName }
        let glyph = trigger == "autoRamadan" ? "🌙" : "🕗"
        return "\(glyph) \(newLabel)"
    }

    /// Formatted relative countdown string, e.g. "2h 14m" or "32m"
    var countdown: String {
        let interval = nextPrayerTime.timeIntervalSince(date)
        guard interval > 0 else { return "Now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
