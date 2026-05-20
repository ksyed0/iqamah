import IqamahCore
import UserNotifications

@MainActor
final class WatchNotificationScheduler {
    static let shared = WatchNotificationScheduler()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func rescheduleAll(settings: SettingsManager) async {
        let granted = await (try? center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        center.removeAllPendingNotificationRequests()

        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier) else { return }

        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for dayOffset in 0 ..< 7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = try? calc.calculate(for: day) else { continue }

            for prayer in times.prayers {
                guard settings.isPrayerEnabled(prayer.name),
                      prayer.name != "Sunrise",
                      prayer.time > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Time for \(prayer.name)"
                content.subtitle = settings.activeCityName
                content.sound = .default
                content.interruptionLevel = .timeSensitive

                let id = "watch.prayer.\(prayer.name).\(formatter.string(from: day))"
                let comps = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: prayer.time
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                try? await center.add(
                    UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                )
            }
        }
    }

    func cancel() {
        center.removeAllPendingNotificationRequests()
    }
}
