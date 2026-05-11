#if os(iOS)
    import ActivityKit
    import Foundation

    /// Shared Live Activity attributes — must be identical between the iOS host app and
    /// the IqamahLiveActivity extension so ActivityKit can match them at runtime.
    struct PrayerActivityAttributes: ActivityAttributes {
        let cityName: String
        let methodName: String

        struct ContentState: Codable, Hashable {
            let nextPrayerName: String
            let nextPrayerTime: Date
            let followingPrayerName: String
            let moonPhase: Double
            let hijriDateString: String
        }
    }
#endif
