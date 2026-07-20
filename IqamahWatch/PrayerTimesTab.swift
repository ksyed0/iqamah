import IqamahCore
import SwiftUI

struct PrayerTimesTab: View {
    @EnvironmentObject private var settings: SettingsManager
    @State private var prayers: [(name: String, time: Date)] = []
    @State private var nextPrayerName: String = ""
    @State private var sunnahTimes: SunnahTimes?

    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text(hijriHeader)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 8)

                    VStack(spacing: 2) {
                        ForEach(prayers, id: \.name) { prayer in
                            PrayerRow(
                                prayer: prayer,
                                isNext: prayer.name == nextPrayerName,
                                gold: gold,
                                timeString: formattedTime(prayer.time),
                                displayName: displayName(for: prayer)
                            )
                        }
                    }

                    if settings.showSunnahTimes, let sunnah = sunnahTimes {
                        NavigationLink(destination: SunnahTimesWatchView(sunnahTimes: sunnah, use24Hour: settings.use24HourTime)) {
                            HStack {
                                Text("Sunnah Times")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(gold.opacity(0.85))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .onAppear { loadPrayers() }
        .onChange(of: settings.calculationMethod) { _, _ in loadPrayers() }
        .onChange(of: settings.asrMethod) { _, _ in loadPrayers() }
        // Reload when city changes (manual selection or GPS update)
        .onChange(of: settings.locationSource) { _, _ in loadPrayers() }
        .onChange(of: settings.gpsLocality) { _, _ in loadPrayers() }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = settings.use24HourTime ? "HH:mm" : "h:mm"
        return f.string(from: date)
    }

    /// AC-0369 (watchOS): apply FastingLabelFormatter relabel within 2h window.
    private func displayName(for prayer: (name: String, time: Date)) -> String {
        let tz = TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current
        let state = FastingModeEngine.evaluate(
            for: Date(),
            settings: settings.fastingModeSettings,
            calculationMethod: settings.calculationMethod,
            hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
            timezone: tz
        )
        return FastingLabelFormatter.relabel(
            prayerName: prayer.name,
            prayerTime: prayer.time,
            currentTime: Date(),
            state: state
        )
    }

    private var hijriHeader: String {
        let cal = Calendar(identifier: .islamicUmmAlQura)
        var c = cal.dateComponents([.day, .month, .year], from: Date())
        c.day = (c.day ?? 1) + settings.hijriDayOffset
        let months = ["Muharram", "Safar", "Rabi' I", "Rabi' II",
                      "Jumada I", "Jumada II", "Rajab", "Sha'ban",
                      "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"]
        let monthIdx = (c.month ?? 1) - 1
        let monthName = monthIdx >= 0 && monthIdx < 12 ? months[monthIdx] : ""
        let dayName = Date().formatted(.dateTime.weekday(.abbreviated)).uppercased()
        return "\(c.day ?? 1) \(monthName.uppercased()) \(c.year ?? 1447) · \(dayName)"
    }

    private func loadPrayers() {
        guard let coord = settings.activeCoordinate,
              let tz = TimeZone(identifier: settings.activeTimezoneIdentifier) else { return }
        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: tz,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        guard let times = try? calc.calculate(for: Date()) else { return }
        prayers = times.prayers
        nextPrayerName = times.prayers
            .first(where: { $0.time > Date() && $0.name != "Sunrise" })?.name ?? ""

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        if let tomorrowTimes = try? calc.calculate(for: tomorrow) {
            sunnahTimes = times.sunnahTimes(nextFajr: tomorrowTimes.fajr)
        }
    }
}

private struct PrayerRow: View {
    let prayer: (name: String, time: Date)
    let isNext: Bool
    let gold: Color
    let timeString: String
    let displayName: String

    var body: some View {
        let font: Font = isNext ? .system(size: 13, weight: .bold) : .system(size: 13)
        HStack {
            Text(displayName).font(font)
            Spacer()
            Text(timeString).font(font)
        }
        .foregroundStyle(isNext ? gold : .primary)
        .opacity(prayer.time < Date() ? 0.28 : 1.0)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(rowBackground)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isNext {
            gold.opacity(0.12)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Sunnah Times Watch View

struct SunnahTimesWatchView: View {
    let sunnahTimes: SunnahTimes
    let use24Hour: Bool

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return f
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                SunnahWatchRow(
                    name: "Tahajjud",
                    icon: "moon.zzz.fill",
                    start: sunnahTimes.tahajjudStart,
                    end: sunnahTimes.tahajjudEnd,
                    formatter: formatter
                )
                SunnahWatchRow(
                    name: "Duha",
                    icon: "sun.haze.fill",
                    start: sunnahTimes.duhaStart,
                    end: sunnahTimes.duhaEnd,
                    formatter: formatter
                )
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Sunnah")
    }
}

private struct SunnahWatchRow: View {
    let name: String
    let icon: String
    let start: Date
    let end: Date
    let formatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(name, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
            Text("\(formatter.string(from: start)) – \(formatter.string(from: end))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
        )
    }
}
