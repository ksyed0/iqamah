import Foundation

/// Windows for the two principal Sunnah prayer periods derived from today's obligatory times.
public struct SunnahTimes {
    /// Start of the Duha window (15 min after Sunrise).
    public let duhaStart: Date
    /// End of the Duha window (15 min before Dhuhr).
    public let duhaEnd: Date
    /// Start of the Tahajjud window — first moment of the last third of the Isha → Fajr night.
    public let tahajjudStart: Date
    /// End of the Tahajjud window — identical to the next day's Fajr.
    public let tahajjudEnd: Date
}

extension PrayerTimes {
    /// Derives Sunnah prayer windows from today's obligatory times.
    ///
    /// - Parameter nextFajr: Tomorrow's Fajr time, used to bound the Tahajjud window.
    public func sunnahTimes(nextFajr: Date) -> SunnahTimes {
        let nightDuration = nextFajr.timeIntervalSince(isha)
        return SunnahTimes(
            duhaStart: sunrise.addingTimeInterval(15 * 60),
            duhaEnd: dhuhr.addingTimeInterval(-15 * 60),
            tahajjudStart: isha.addingTimeInterval(nightDuration * (2.0 / 3.0)),
            tahajjudEnd: nextFajr
        )
    }
}
