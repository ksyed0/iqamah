import ActivityKit
import Foundation

public struct PrayerActivityAttributes: ActivityAttributes {
    public let cityName: String
    public let methodName: String

    public init(cityName: String, methodName: String) {
        self.cityName = cityName
        self.methodName = methodName
    }

    public struct ContentState: Codable, Hashable {
        public let nextPrayerName: String
        public let nextPrayerTime: Date
        public let followingPrayerName: String
        public let moonPhase: Double
        public let hijriDateString: String

        public init(
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
