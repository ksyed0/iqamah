import Foundation

public struct PrayerTimes {
    public let fajr: Date
    public let sunrise: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date
    public let date: Date

    public init(fajr: Date, sunrise: Date, dhuhr: Date, asr: Date, maghrib: Date, isha: Date, date: Date) {
        self.fajr = fajr
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.date = date
    }

    public var prayers: [(name: String, time: Date)] {
        [
            ("Fajr", fajr),
            ("Sunrise", sunrise),
            ("Dhuhr", dhuhr),
            ("Asr", asr),
            ("Maghrib", maghrib),
            ("Isha", isha),
        ]
    }

    public func formattedTime(for prayer: Date, using formatter: DateFormatter) -> String {
        formatter.string(from: prayer)
    }
}

extension PrayerTimes {
    public static func timeFormatter(for timezone: TimeZone = .current, use24Hour: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        formatter.timeZone = timezone
        return formatter
    }
}
