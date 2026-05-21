import ActivityKit
import Foundation

/// Live Activity attributes — single source of truth, compiled into both the
/// iqamah-iOS app target and the IqamahLiveActivity widget extension via
/// multi-target membership in iqamah.xcodeproj. ActivityKit matches Activity
/// instances by encoded representation, so the two targets must compile an
/// identical type definition — which a single file guarantees.
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
