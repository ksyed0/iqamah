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

    struct ContentState: Codable, Hashable {
        let nextPrayerName: String
        let nextPrayerTime: Date
        let followingPrayerName: String
        let moonPhase: Double
        let hijriDateString: String
        // v1.6 additions (AC-0370) — optional with default-nil so v1.5 in-flight
        // activities decode cleanly under v1.6.
        var fastingActive: Bool?
        var fastingTriggerRaw: String?

        init(
            nextPrayerName: String, nextPrayerTime: Date,
            followingPrayerName: String, moonPhase: Double, hijriDateString: String,
            fastingActive: Bool? = nil, fastingTriggerRaw: String? = nil
        ) {
            self.nextPrayerName = nextPrayerName
            self.nextPrayerTime = nextPrayerTime
            self.followingPrayerName = followingPrayerName
            self.moonPhase = moonPhase
            self.hijriDateString = hijriDateString
            self.fastingActive = fastingActive
            self.fastingTriggerRaw = fastingTriggerRaw
        }

        // Forward-compatible decoder — `fastingActive` and `fastingTriggerRaw`
        // are missing from v1.5 payloads; default to nil rather than throw.
        enum CodingKeys: String, CodingKey {
            case nextPrayerName, nextPrayerTime, followingPrayerName
            case moonPhase, hijriDateString
            case fastingActive, fastingTriggerRaw
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                nextPrayerName: c.decode(String.self, forKey: .nextPrayerName),
                nextPrayerTime: c.decode(Date.self, forKey: .nextPrayerTime),
                followingPrayerName: c.decode(String.self, forKey: .followingPrayerName),
                moonPhase: c.decode(Double.self, forKey: .moonPhase),
                hijriDateString: c.decode(String.self, forKey: .hijriDateString),
                fastingActive: c.decodeIfPresent(Bool.self, forKey: .fastingActive),
                fastingTriggerRaw: c.decodeIfPresent(String.self, forKey: .fastingTriggerRaw)
            )
        }
    }
}
