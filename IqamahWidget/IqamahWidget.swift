import IqamahCore
import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: Date
    let cityName: String
    let methodName: String // "" in stub entries
    let todaysPrayers: [(name: String, time: Date)] // excludes Sunrise
    let hijriDateString: String // "" in stub entries
    let sunriseTime: Date? // nil in stub entries
    // AC-0370: Fasting Mode state for the moment this entry becomes active.
    let fastingActive: Bool
    let fastingTriggerRaw: String?

    var countdown: String {
        let interval = nextPrayerTime.timeIntervalSince(date)
        guard interval > 0 else { return "Now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

// MARK: - Timeline provider

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> PrayerEntry {
        PrayerEntry(
            date: Date(),
            nextPrayerName: "Dhuhr",
            nextPrayerTime: Date().addingTimeInterval(3600),
            cityName: "Makkah",
            methodName: "MWL",
            todaysPrayers: [
                ("Fajr", Date().addingTimeInterval(-7200)),
                ("Dhuhr", Date().addingTimeInterval(3600)),
                ("Asr", Date().addingTimeInterval(10800)),
                ("Maghrib", Date().addingTimeInterval(18000)),
                ("Isha", Date().addingTimeInterval(25200)),
            ],
            hijriDateString: "9 Dhu al-Hijjah 1447",
            sunriseTime: Date().addingTimeInterval(-5400),
            fastingActive: false,
            fastingTriggerRaw: nil
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()

        // Generate one entry per prayer transition for today + tomorrow.
        // WidgetKit reads entries from local cache at the right moment — no
        // background wake needed. Using .atEnd asks WidgetKit to call
        // getTimeline again once all entries expire (after tomorrow's last prayer).
        var entries: [PrayerEntry] = [makeEntry(for: now)] // "right now" entry

        let settings = SettingsManager.shared
        if let coord = settings.activeCoordinate,
           let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier) {
            let calc = PrayerCalculator(
                coordinate: coord, timezone: timezone,
                method: settings.calculationMethod, asrMethod: settings.asrMethod
            )
            for dayOffset in 0 ... 1 {
                guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
                      let times = try? calc.calculate(for: day)
                else { continue }
                for prayer in times.prayers where prayer.name != "Sunrise" && prayer.time > now {
                    // Each entry becomes active exactly when that prayer starts.
                    entries.append(makeEntry(for: prayer.time))
                }
            }
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(for date: Date) -> PrayerEntry {
        let settings = SettingsManager.shared
        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier)
        else {
            return PrayerEntry(date: date, nextPrayerName: "—", nextPrayerTime: date,
                               cityName: "—", methodName: "", todaysPrayers: [], hijriDateString: "",
                               sunriseTime: nil, fastingActive: false, fastingTriggerRaw: nil)
        }

        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )

        let cityName = settings.activeCityName.isEmpty ? "—" : settings.activeCityName
        let methodName = settings.calculationMethod.shortName
        let hijri = hijriDateString(for: date, offset: settings.hijriDayOffset)

        // Full day prayer list (excluding Sunrise) + capture sunrise separately
        let todayTimes = try? calc.calculate(for: date)
        let todaysPrayers: [(name: String, time: Date)] = todayTimes?.prayers
            .filter { $0.name != "Sunrise" } ?? []
        let sunriseTime: Date? = todayTimes?.prayers.first { $0.name == "Sunrise" }?.time

        // AC-0370: evaluate Fasting Mode state once per entry date.
        let fastingState = FastingModeEngine.evaluate(
            for: date,
            settings: settings.fastingModeSettings,
            calculationMethod: settings.calculationMethod,
            hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
            timezone: timezone
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
                    cityName: cityName,
                    methodName: methodName,
                    todaysPrayers: todaysPrayers,
                    hijriDateString: hijri,
                    sunriseTime: sunriseTime,
                    fastingActive: fastingState.isActive,
                    fastingTriggerRaw: fastingState.trigger?.rawValue
                )
            }
        }

        return PrayerEntry(date: date, nextPrayerName: "—", nextPrayerTime: date,
                           cityName: cityName, methodName: methodName,
                           todaysPrayers: todaysPrayers, hijriDateString: hijri,
                           sunriseTime: sunriseTime,
                           fastingActive: fastingState.isActive,
                           fastingTriggerRaw: fastingState.trigger?.rawValue)
    }
}

// MARK: - Fasting Mode relabel helper (AC-0370)

//
// Widgets only have row name strings; we re-derive the relabel using the
// engine's contract — Fajr→Suhoor / Maghrib→Iftar within a 2h window when
// `fastingActive` is true.
private let widgetRelabelWindow: TimeInterval = 2 * 60 * 60

func displayedPrayerName(
    _ prayerName: String,
    prayerTime: Date,
    referenceDate: Date,
    fastingActive: Bool,
    fastingTriggerRaw: String?
) -> String {
    guard fastingActive, let trigger = fastingTriggerRaw, !trigger.isEmpty else {
        return prayerName
    }
    let newLabel: String
    switch prayerName {
    case "Fajr": newLabel = "Suhoor"
    case "Maghrib": newLabel = "Iftar"
    default: return prayerName
    }
    let secondsUntil = prayerTime.timeIntervalSince(referenceDate)
    guard (0 ... widgetRelabelWindow).contains(secondsUntil) else { return prayerName }
    let glyph = trigger == "autoRamadan" ? "🌙" : "🕗"
    return "\(glyph) \(newLabel)"
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
        case .systemLarge, .systemExtraLarge:
            #if os(macOS)
                macOSLargeWidgetView(entry: entry)
            #else
                LargeWidgetView(entry: entry)
            #endif
        case .accessoryRectangular:
            lockScreenView
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
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
            Text(displayedPrayerName(
                entry.nextPrayerName,
                prayerTime: entry.nextPrayerTime,
                referenceDate: entry.date,
                fastingActive: entry.fastingActive,
                fastingTriggerRaw: entry.fastingTriggerRaw
            ))
            .font(.title3.bold())
            Text(entry.nextPrayerTime, style: .relative)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        let timeFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm"
            return f
        }()
        let prayers = entry.todaysPrayers.filter { $0.name != "Sunrise" }
        // Parse "9 Dhu al-Hijjah 1447" → day "9" + rest
        let hijriParts = entry.hijriDateString.split(separator: " ", maxSplits: 1)
        let hijriDay = hijriParts.first.map(String.init) ?? ""
        let hijriRest = hijriParts.dropFirst().first.map(String.init) ?? ""

        return VStack(spacing: 0) {
            // ── Top row: Hijri date left, Sunrise right ──────────────────
            HStack(alignment: .top) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(hijriDay)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(hijriRest.isEmpty ? entry.hijriDateString : hijriRest)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(entry.cityName)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let sr = entry.sunriseTime {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow.opacity(0.85))
                            Text("Sunrise")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(timeFmt.string(from: sr))
                            .font(.system(size: 16, weight: .bold).monospacedDigit())
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().opacity(0.4).padding(.horizontal, 8)

            // ── Prayer columns ────────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(prayers, id: \.name) { prayer in
                    let isNext = prayer.name == entry.nextPrayerName
                    let isPast = prayer.time < entry.date
                    let relabeled = displayedPrayerName(
                        prayer.name,
                        prayerTime: prayer.time,
                        referenceDate: entry.date,
                        fastingActive: entry.fastingActive,
                        fastingTriggerRaw: entry.fastingTriggerRaw
                    )
                    VStack(spacing: 2) {
                        Text(relabeled == prayer.name && prayer.name == "Dhuhr" ? "Zuhr" : relabeled)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isNext ? gold : .secondary)
                        Text(timeFmt.string(from: prayer.time))
                            .font(.system(size: 14, weight: isNext ? .bold : .medium).monospacedDigit())
                            .foregroundStyle(isNext ? gold : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(isPast && !isNext ? 0.35 : 1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var gold: Color { Color(red: 0.88, green: 0.69, blue: 0.06) }

    private var lockScreenView: some View {
        HStack {
            Text(displayedPrayerName(
                entry.nextPrayerName,
                prayerTime: entry.nextPrayerTime,
                referenceDate: entry.date,
                fastingActive: entry.fastingActive,
                fastingTriggerRaw: entry.fastingTriggerRaw
            ))
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

    // macOS Notification Center supports systemSmall/Medium/Large only.
    // iOS/iPadOS also support ExtraLarge and lock-screen accessory families.
    private static var supportedFamilies: [WidgetFamily] {
        #if os(macOS)
            return [.systemSmall, .systemMedium, .systemLarge]
        #else
            return [
                .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
                .accessoryRectangular, .accessoryCircular, .accessoryInline,
            ]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            IqamahWidgetView(entry: entry)
        }
        .configurationDisplayName("Iqamah")
        .description("Next prayer countdown for your location.")
        .supportedFamilies(Self.supportedFamilies)
    }
}

// MARK: - Widget bundle

@main
struct IqamahWidgetBundle: WidgetBundle {
    var body: some Widget {
        IqamahWidget()
    }
}
