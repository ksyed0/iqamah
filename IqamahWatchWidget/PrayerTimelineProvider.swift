import Foundation
import IqamahCore
import WidgetKit

struct PrayerTimelineProvider: TimelineProvider {
    private let defaults: UserDefaults

    /// Production init uses the live App Group store.
    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.fablesoft.iqamah") ?? .standard) {
        self.defaults = defaults
    }

    func placeholder(in _: Context) -> PrayerEntry {
        placeholder()
    }

    func getSnapshot(in _: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entries = buildEntries(from: Date())
        completion(Timeline(entries: entries, policy: refreshPolicy(for: entries)))
    }

    // MARK: - Internal (internal for testability)

    func placeholder() -> PrayerEntry {
        PrayerEntry(
            date: Date(),
            nextPrayerName: "Asr",
            nextPrayerTime: Date().addingTimeInterval(3600),
            cityName: "—",
            methodName: "—"
        )
    }

    func buildEntries(from now: Date) -> [PrayerEntry] {
        let settings = SettingsManager(userDefaults: defaults)
        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier)
        else { return [placeholder()] }

        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        let cityName = settings.activeCityName.isEmpty ? "—" : settings.activeCityName
        let methodName = settings.calculationMethod.shortName

        var entries: [PrayerEntry] = []
        var cursor = now

        for dayOffset in 0 ... 1 {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
                  let times = try? calc.calculate(for: day)
            else { continue }

            for prayer in times.prayers where prayer.name != "Sunrise" && prayer.time > cursor {
                entries.append(PrayerEntry(
                    date: cursor,
                    nextPrayerName: prayer.name,
                    nextPrayerTime: prayer.time,
                    cityName: cityName,
                    methodName: methodName
                ))
                cursor = prayer.time
            }
        }

        return entries.isEmpty ? [placeholder()] : entries
    }

    func refreshPolicy(for entries: [PrayerEntry]) -> TimelineReloadPolicy {
        guard let last = entries.last else { return .after(Date().addingTimeInterval(3600)) }
        return .after(last.nextPrayerTime)
    }

    private func makeEntry(for date: Date) -> PrayerEntry {
        buildEntries(from: date).first ?? placeholder()
    }
}
