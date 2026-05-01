import Foundation

struct PrayerTimes {
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date
    let date: Date

    var prayers: [(name: String, time: Date)] {
        [
            ("Fajr", fajr),
            ("Sunrise", sunrise),
            ("Dhuhr", dhuhr),
            ("Asr", asr),
            ("Maghrib", maghrib),
            ("Isha", isha),
        ]
    }

    func formattedTime(for prayer: Date, using formatter: DateFormatter) -> String {
        formatter.string(from: prayer)
    }
}

extension PrayerTimes {
    static func timeFormatter(for timezone: TimeZone = .current, use24Hour: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        formatter.timeZone = timezone
        return formatter
    }
}
