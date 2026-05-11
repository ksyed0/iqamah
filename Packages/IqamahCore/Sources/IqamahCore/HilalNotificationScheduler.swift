#if canImport(UserNotifications)
    import Foundation
    import UserNotifications

    /// Schedules a local notification for the d29 Hilal Watch evening (~30 min before sunset).
    /// Called when `hilalNotificationEnabled` is toggled on, and re-called each Hijri month rollover.
    public final class HilalNotificationScheduler: Sendable {
        public static let shared = HilalNotificationScheduler()
        private init() {}

        private let notificationID = "hilal.watch.d29"

        /// Schedules (or re-schedules) the d29 notification for the current or upcoming Hijri month.
        /// Pass `latitude` and `longitude` for the observer; pass `nil` to cancel.
        public func scheduleNextWatchEvening(
            latitude: Double,
            longitude: Double
        ) async {
            #if os(iOS) || os(watchOS)
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [notificationID])

                // Find the next new moon
                guard let newMoon = NewMoon.search(startDate: Date(), daysAhead: 35) else { return }

                // d29 sunset at observer location (d29 = 1 day after new moon)
                let d29JD = newMoon.julianDay + 1
                let sunsetJD = SunPosition.sunsetJD(
                    julianDay: d29JD,
                    latitude: latitude,
                    longitude: longitude
                )
                // Notify 30 min before sunset
                let notifyDate = Date.fromJulianDay(sunsetJD).addingTimeInterval(-30 * 60)
                guard notifyDate > Date() else { return } // already past

                let content = UNMutableNotificationContent()
                content.title = "Hilal Watch Tonight"
                content.body = "Look for the crescent moon ~30 minutes after sunset."
                content.sound = .default
                content.userInfo = ["destination": "hilal-watch"]

                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: notifyDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: notificationID,
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            #endif
        }

        /// Cancels any pending Hilal Watch evening notification.
        public func cancel() {
            #if os(iOS) || os(watchOS)
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: [notificationID])
            #endif
        }
    }
#endif
