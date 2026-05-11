#if os(iOS)
    import ActivityKit
    import Foundation

    /// Shared Live Activity attributes — must be identical between the iOS host app and
    /// the IqamahLiveActivity extension so ActivityKit can match them at runtime.
    struct PrayerActivityAttributes: ActivityAttributes {
        let cityName: String
        let methodName: String

        init(cityName: String, methodName: String) {
            self.cityName = cityName
            self.methodName = methodName
        }

        struct ContentState: Codable, Hashable {
            let nextPrayerName: String
            let nextPrayerTime: Date
            let followingPrayerName: String
            let moonPhase: Double
            let hijriDateString: String

            init(
                nextPrayerName: String, nextPrayerTime: Date,
                followingPrayerName: String, moonPhase: Double, hijriDateString: String
            ) {
                self.nextPrayerName = nextPrayerName
                self.nextPrayerTime = nextPrayerTime
                self.followingPrayerName = followingPrayerName
                self.moonPhase = moonPhase
                self.hijriDateString = hijriDateString
            }
        }
    }
#endif
