#if os(iOS)
    import Foundation
    import IqamahCore
    import UserNotifications

    /// Schedules local prayer-time notifications for the next 7 days.
    ///
    /// Called whenever settings change (city, method, enabledPrayers) and on
    /// each app-active transition. At most 35 pending notifications (7 days × 5
    /// prayers) — well within iOS's 64-notification limit.
    @MainActor
    final class NotificationScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
        static let shared = NotificationScheduler()

        private let center = UNUserNotificationCenter.current()

        override private init() {
            super.init()
            center.delegate = self
        }

        // MARK: - Authorisation

        /// Requests notification authorisation if not yet determined.
        /// Returns true if authorised (or already authorised).
        func requestAuthorizationIfNeeded() async -> Bool {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                return await (try? center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            case .authorized, .provisional, .ephemeral:
                return true
            case .denied:
                return false
            @unknown default:
                return false
            }
        }

        // MARK: - Scheduling

        /// Cancels all pending prayer notifications and reschedules 7 days ahead.
        func rescheduleAll() async {
            guard await requestAuthorizationIfNeeded() else { return }
            center.removeAllPendingNotificationRequests()

            let settings = SettingsManager.shared
            guard let coord = settings.activeCoordinate else { return }
            let timezoneId = settings.activeTimezoneIdentifier
            guard let timezone = TimeZone(identifier: timezoneId) else { return }

            let calc = PrayerCalculator(
                coordinate: coord,
                timezone: timezone,
                method: settings.calculationMethod,
                asrMethod: settings.asrMethod
            )

            let calendar = Calendar(identifier: .gregorian)
            let now = Date()

            for dayOffset in 0 ..< 7 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                guard let times = try? calc.calculate(for: day) else { continue }

                for prayer in times.prayers {
                    guard settings.isPrayerEnabled(prayer.name) else { continue }
                    guard prayer.time > now else { continue } // skip times already past today
                    let request = makeRequest(name: prayer.name, time: prayer.time, day: day, settings: settings)
                    try? await center.add(request)
                }
            }
        }

        // MARK: - Request construction

        private func makeRequest(
            name: String,
            time: Date,
            day: Date,
            settings: SettingsManager
        ) -> UNNotificationRequest {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let id = "prayer.\(name).\(formatter.string(from: day))"

            let content = UNMutableNotificationContent()
            content.title = "Iqamah"
            content.body = "It is time for \(name)"
            content.sound = resolveSound(for: name, settings: settings)
            content.userInfo = ["prayerName": name]
            // Break through Focus/DND — prayer times are time-bound obligations.
            // .timeSensitive doesn't need a special Apple entitlement (unlike .critical).
            content.interruptionLevel = .timeSensitive

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: time
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }

        private func resolveSound(for prayer: String, settings: SettingsManager) -> UNNotificationSound {
            // Use default system sound if prayer is muted
            guard !settings.isPrayerMuted(prayer) else { return .default }

            // Resolve via the public Adhaan API — Bundle.module is internal to IqamahCore
            let adhaan = settings.getAdhaan(for: prayer)
            guard let notifFilename = adhaan.notificationSoundFilename else { return .default }

            return UNNotificationSound(named: UNNotificationSoundName(notifFilename))
        }

        // MARK: - UNUserNotificationCenterDelegate

        /// Displays the notification as a banner even while the app is in the foreground.
        nonisolated func userNotificationCenter(
            _: UNUserNotificationCenter,
            willPresent _: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .sound])
        }

        /// Handles a tap on a prayer notification — posts a notification to open the Times tab.
        nonisolated func userNotificationCenter(
            _: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            if response.notification.request.content.userInfo["prayerName"] != nil {
                NotificationCenter.default.post(name: .openPrayerTimesTab, object: nil)
            }
            completionHandler()
        }
    }

    public extension Notification.Name {
        /// Posted when a prayer notification is tapped — tells the iOS root view to switch to Times tab.
        static let openPrayerTimesTab = Notification.Name("openPrayerTimesTab")
    }
#endif
