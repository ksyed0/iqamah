import IqamahCore
import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: PrayerEntry
    private let gold = Color(red: 1.0, green: 0.839, blue: 0.039)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("IQAMAH")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(entry.nextPrayerTime, style: .relative)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(gold)
            }
            .padding(.bottom, 6)

            Divider().padding(.bottom, 8)

            ForEach(entry.todaysPrayers, id: \.name) { prayer in
                let isNext = prayer.name == entry.nextPrayerName
                let isPast = prayer.time < Date()
                HStack {
                    Text(prayer.name)
                        .font(.system(size: 14, weight: isNext ? .bold : .regular))
                        .foregroundStyle(isNext ? gold : .primary)
                    Spacer()
                    Text(prayer.time, style: .time)
                        .font(.system(size: 14, weight: isNext ? .bold : .regular).monospacedDigit())
                        .foregroundStyle(isNext ? gold : .primary)
                }
                .padding(.horizontal, isNext ? 6 : 0)
                .padding(.vertical, 4)
                .background(isNext ? gold.opacity(0.10) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .opacity(isPast ? 0.30 : 1.0)
            }

            Spacer()

            if !entry.hijriDateString.isEmpty {
                Text(entry.hijriDateString)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
