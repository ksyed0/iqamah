import IqamahCore
import SwiftUI

struct PrayerTimesTab: View {
    @EnvironmentObject private var settings: SettingsManager
    @State private var prayers: [(name: String, time: Date)] = []
    @State private var nextPrayerName: String = ""

    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        VStack(spacing: 0) {
            Text(hijriHeader)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 4)

            List {
                ForEach(prayers, id: \.name) { prayer in
                    PrayerRow(
                        prayer: prayer,
                        isNext: prayer.name == nextPrayerName,
                        gold: gold,
                        timeString: formattedTime(prayer.time)
                    )
                }
            }
            .listStyle(.plain)
        }
        .onAppear { loadPrayers() }
        .onChange(of: settings.calculationMethod) { _, _ in loadPrayers() }
        .onChange(of: settings.asrMethod) { _, _ in loadPrayers() }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = settings.use24HourTime ? "HH:mm" : "h:mm"
        return f.string(from: date)
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
    }
}

private struct PrayerRow: View {
    let prayer: (name: String, time: Date)
    let isNext: Bool
    let gold: Color
    let timeString: String

    var body: some View {
        let font: Font = isNext ? .system(size: 13, weight: .bold) : .system(size: 13)
        HStack {
            Text(prayer.name).font(font)
            Spacer()
            Text(timeString).font(font)
        }
        .foregroundStyle(isNext ? gold : .primary)
        .opacity(prayer.time < Date() ? 0.28 : 1.0)
        .listRowInsets(rowInsets)
        .listRowBackground(rowBackground)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isNext {
            gold.opacity(0.12).clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Color.clear
        }
    }

    // Compact insets keep all 5 prayers visible without scrolling on 41mm+
    private var rowInsets: EdgeInsets { EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0) }
}
