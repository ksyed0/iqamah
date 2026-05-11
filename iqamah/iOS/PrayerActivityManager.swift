#if os(iOS)
    import ActivityKit
    import Foundation
    import IqamahCore

    /// Manages the lifecycle of the prayer-times Live Activity.
    /// Call `startOrUpdateActivity(settings:)` on every app-active event.
    @MainActor
    final class PrayerActivityManager {
        static let shared = PrayerActivityManager()
        private init() {}

        private var currentActivity: Activity<PrayerActivityAttributes>?

        // MARK: - Public API

        func startOrUpdateActivity(settings: SettingsManager) async {
            guard ActivityAuthorizationInfo().areActivitiesEnabled,
                  settings.liveActivityEnabled else {
                await endActivity()
                return
            }
            guard let state = buildContentState(settings: settings) else { return }

            if let activity = currentActivity {
                await activity.update(using: state, alertConfiguration: nil)
            } else {
                let attributes = PrayerActivityAttributes(
                    cityName: settings.activeCityName,
                    methodName: settings.calculationMethod.shortName
                )
                do {
                    currentActivity = try Activity.request(
                        attributes: attributes,
                        contentState: state,
                        pushType: nil
                    )
                } catch {
                    print("[PrayerActivityManager] Failed to start activity: \(error)")
                }
            }
        }

        func endActivity() async {
            await currentActivity?.end(using: nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }

        // MARK: - Private

        private func buildContentState(settings: SettingsManager) -> PrayerActivityAttributes.ContentState? {
            guard let coord = settings.activeCoordinate,
                  let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier) else { return nil }

            let calc = PrayerCalculator(
                coordinate: coord, timezone: timezone,
                method: settings.calculationMethod, asrMethod: settings.asrMethod
            )
            let now = Date()
            var nextPrayer: (name: String, time: Date)?
            var followingPrayer: (name: String, time: Date)?

            for dayOffset in 0 ... 1 {
                guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
                      let times = try? calc.calculate(for: day) else { continue }
                let upcoming = times.prayers.filter { $0.time > now && $0.name != "Sunrise" }
                for prayer in upcoming {
                    if nextPrayer == nil {
                        nextPrayer = (prayer.name, prayer.time)
                    } else if followingPrayer == nil {
                        followingPrayer = (prayer.name, prayer.time)
                        break
                    }
                }
                if followingPrayer != nil { break }
            }

            guard let next = nextPrayer else { return nil }

            return PrayerActivityAttributes.ContentState(
                nextPrayerName: next.name,
                nextPrayerTime: next.time,
                followingPrayerName: followingPrayer?.name ?? "",
                moonPhase: moonPhase(for: now),
                hijriDateString: hijriDateString(for: now, offset: settings.hijriDayOffset)
            )
        }
    }
#endif
