import IqamahCore
import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: Date
    let cityName: String
}

// MARK: - Timeline provider

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> PrayerEntry {
        PrayerEntry(
            date: Date(),
            nextPrayerName: "Dhuhr",
            nextPrayerTime: Date().addingTimeInterval(3600),
            cityName: "Makkah"
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(for: now)
        // Refresh after next prayer time (or in 1 hour if no prayer found)
        let nextRefresh = entry.nextPrayerTime > now ? entry.nextPrayerTime : now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry(for date: Date) -> PrayerEntry {
        let settings = SettingsManager.shared
        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier)
        else {
            return PrayerEntry(date: date, nextPrayerName: "—", nextPrayerTime: date, cityName: "—")
        }

        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )

        // Find next upcoming prayer (today or tomorrow if all past)
        for dayOffset in 0 ... 1 {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: date),
                  let times = try? calc.calculate(for: day)
            else { continue }
            if let next = times.prayers.first(where: { $0.time > date && $0.name != "Sunrise" }) {
                return PrayerEntry(
                    date: date,
                    nextPrayerName: next.name,
                    nextPrayerTime: next.time,
                    cityName: settings.activeCityName
                )
            }
        }

        return PrayerEntry(date: date, nextPrayerName: "—", nextPrayerTime: date, cityName: "—")
    }
}

// MARK: - Widget views

struct IqamahWidgetView: View {
    var entry: PrayerEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            lockScreenView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.cityName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(entry.nextPrayerName)
                .font(.title3.bold())
            Text(entry.nextPrayerTime, style: .relative)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.cityName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.nextPrayerName)
                    .font(.title2.bold())
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.nextPrayerTime, style: .relative)
                    .font(.title3.monospacedDigit().bold())
                Text(entry.nextPrayerTime, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var lockScreenView: some View {
        HStack {
            Text(entry.nextPrayerName)
                .font(.headline)
            Spacer()
            Text(entry.nextPrayerTime, style: .relative)
                .font(.caption.monospacedDigit())
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget configuration

struct IqamahWidget: Widget {
    let kind = "IqamahWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            IqamahWidgetView(entry: entry)
        }
        .configurationDisplayName("Iqamah")
        .description("Next prayer countdown for your location.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Widget bundle

@main
struct IqamahWidgetBundle: WidgetBundle {
    var body: some Widget {
        IqamahWidget()
    }
}
