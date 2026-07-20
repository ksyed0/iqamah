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
        private var rolloverTimer: Timer?

        // MARK: - Public API

        func startOrUpdateActivity(settings: SettingsManager) async {
            guard ActivityAuthorizationInfo().areActivitiesEnabled,
                  settings.liveActivityEnabled else {
                await endActivity()
                return
            }
            guard let state = buildContentState(settings: settings) else { return }

            // staleDate ~1 minute after the next prayer time so iOS dims the
            // Live Activity and prompts a refresh once it's passed (avoids
            // the count-up timer issue where Text(date, style: .timer)
            // flips to count-up after the target passes).
            let staleDate = state.nextPrayerTime.addingTimeInterval(60)

            // Adopt any surviving activity from a previous session so we never run
            // two concurrent Live Activities (which causes duplicate lock-screen banners).
            if currentActivity == nil {
                let existing = Activity<PrayerActivityAttributes>.activities
                if existing.count > 1 {
                    // End all but the first to remove duplicates
                    for stale in existing.dropFirst() {
                        // iOS 16.2+ API. Pass nil content to preserve whatever
                        // the stale activity was showing at the moment we end it.
                        await stale.end(nil, dismissalPolicy: .immediate)
                    }
                }
                currentActivity = existing.first
            }

            if let activity = currentActivity {
                await activity.update(ActivityContent(state: state, staleDate: staleDate))
            } else {
                let attributes = PrayerActivityAttributes(
                    cityName: settings.activeCityName,
                    methodName: settings.calculationMethod.shortName
                )
                do {
                    currentActivity = try Activity.request(
                        attributes: attributes,
                        content: ActivityContent(state: state, staleDate: staleDate)
                    )
                } catch {
                    print("[PrayerActivityManager] Failed to start activity: \(error)")
                }
            }

            // Schedule a foreground-only rollover so a foregrounded (or recently
            // backgrounded) app advances to the next prayer +1s after the current
            // one passes. Full background reliability still requires push-token
            // LA updates + BGAppRefreshTask (follow-up).
            scheduleRollover(at: state.nextPrayerTime)
        }

        func endActivity() async {
            rolloverTimer?.invalidate()
            rolloverTimer = nil
            if let activity = currentActivity {
                await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }

        private func scheduleRollover(at fireDate: Date) {
            rolloverTimer?.invalidate()
            let delay = max(1, fireDate.timeIntervalSinceNow + 1)
            let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    await self?.startOrUpdateActivity(settings: SettingsManager.shared)
                }
            }
            rolloverTimer = timer
            RunLoop.main.add(timer, forMode: .common)
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
                if followingPrayer != nil {
                    break
                }
            }

            guard let next = nextPrayer else { return nil }

            // AC-0370: include today's Fasting Mode state so the Live Activity
            // can render the Suhoor/Iftar relabel within the 2h window.
            let fastingState = FastingModeEngine.evaluate(
                for: now,
                settings: settings.fastingModeSettings,
                calculationMethod: settings.calculationMethod,
                hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
                timezone: timezone
            )

            return PrayerActivityAttributes.ContentState(
                nextPrayerName: next.name,
                nextPrayerTime: next.time,
                followingPrayerName: followingPrayer?.name ?? "",
                moonPhase: moonPhase(for: now),
                hijriDateString: hijriDateString(for: now, offset: settings.hijriDayOffset),
                fastingActive: fastingState.isActive,
                fastingTriggerRaw: fastingState.trigger?.rawValue
            )
        }
    }
#endif
