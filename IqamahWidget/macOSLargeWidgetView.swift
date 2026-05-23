#if os(macOS)
    import IqamahCore
    import SwiftUI
    import WidgetKit

    struct macOSLargeWidgetView: View {
        let entry: PrayerEntry
        @Environment(\.colorScheme) private var colorScheme

        private var gold: Color {
            colorScheme == .dark
                ? Color(red: 0.88, green: 0.69, blue: 0.06)
                : Color(red: 0.54, green: 0.37, blue: 0.00)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Group {
                        if entry.hijriDateString.isEmpty {
                            Text("IQAMAH")
                        } else {
                            Text("IQAMAH · \(entry.hijriDateString.uppercased())")
                        }
                    }
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
                    .lineLimit(1)
                    Spacer()
                    Text(entry.nextPrayerTime, style: .relative)
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(gold)
                }
                .padding(.bottom, 8)

                Divider().padding(.bottom, 8)

                ForEach(entry.todaysPrayers, id: \.name) { prayer in
                    let isNext = prayer.name == entry.nextPrayerName
                    let isPast = prayer.time < Date()
                    HStack {
                        if isNext {
                            Circle().fill(gold).frame(width: 5, height: 5)
                        }
                        Text(displayedPrayerName(
                            prayer.name,
                            prayerTime: prayer.time,
                            referenceDate: entry.date,
                            fastingActive: entry.fastingActive,
                            fastingTriggerRaw: entry.fastingTriggerRaw
                        ))
                        .font(.system(size: 13, weight: isNext ? .bold : .regular))
                        .foregroundStyle(isNext ? gold : .primary)
                        Spacer()
                        Text(prayer.time, style: .time)
                            .font(.system(size: 13, weight: isNext ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(isNext ? gold : .primary)
                    }
                    .padding(.vertical, 3)
                    .opacity(isPast ? 0.28 : 1.0)
                }

                Divider().padding(.top, 8).padding(.bottom, 6)

                Text("\(entry.cityName) · \(entry.methodName)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
#endif
