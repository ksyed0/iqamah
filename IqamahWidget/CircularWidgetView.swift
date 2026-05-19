import IqamahCore
import SwiftUI
import WidgetKit

struct CircularWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.colorScheme) private var colorScheme

    private var gold: Color {
        colorScheme == .dark
            ? Color(red: 0.88, green: 0.69, blue: 0.06)
            : Color(red: 0.54, green: 0.37, blue: 0.00)
    }

    var body: some View {
        ZStack {
            ProgressView(value: dayProgress)
                .progressViewStyle(.circular)
                .tint(gold)
            VStack(spacing: 0) {
                Text(String(entry.nextPrayerName.prefix(1)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(gold)
                Text(entry.nextPrayerTime, style: .timer)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var dayProgress: Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: entry.date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let total = end.timeIntervalSince(start)
        let elapsed = entry.nextPrayerTime.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }
}
