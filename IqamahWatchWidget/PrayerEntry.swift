import Foundation
import WidgetKit

struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: Date
    let cityName: String
    let methodName: String

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
