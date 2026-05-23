import IqamahCore
import SwiftUI
import WidgetKit

// MARK: - Rectangular

struct RectangularComplicationView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("IQAMAH")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .widgetAccentable()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.displayedNextPrayerName)
                    .font(.system(size: 15, weight: .bold))
                Text(entry.countdown)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.839, blue: 0.039))
                    .widgetAccentable()
            }
            Text("\(entry.cityName) · \(entry.methodName)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Circular

struct CircularComplicationView: View {
    let entry: PrayerEntry

    var body: some View {
        ZStack {
            ProgressView(value: dayProgress)
                .progressViewStyle(.circular)
                .tint(Color(red: 1.0, green: 0.839, blue: 0.039))
                .widgetAccentable()
            VStack(spacing: 0) {
                Text(String(entry.nextPrayerName.prefix(3)))
                    .font(.system(size: 11, weight: .semibold))
                Text(entry.countdown)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
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

// MARK: - Corner

struct CornerComplicationView: View {
    let entry: PrayerEntry

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    Color(red: 1.0, green: 0.839, blue: 0.039),
                    lineWidth: 2
                )
                .widgetAccentable()
            VStack(spacing: 0) {
                Text(String(entry.nextPrayerName.prefix(1)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.839, blue: 0.039))
                    .widgetAccentable()
                Text(entry.countdown)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Inline

struct InlineComplicationView: View {
    let entry: PrayerEntry

    var body: some View {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return Text("\(entry.displayedNextPrayerName) at \(formatter.string(from: entry.nextPrayerTime))")
            .widgetAccentable()
    }
}

// MARK: - Dispatcher

struct IqamahWatchWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        default:
            RectangularComplicationView(entry: entry)
        }
    }
}

// MARK: - Widget + Bundle

struct IqamahWatchComplicationWidget: Widget {
    let kind = "IqamahWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            IqamahWatchWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Iqamah")
        .description("Next prayer countdown on your watch face.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

@main
struct IqamahWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        IqamahWatchComplicationWidget()
    }
}
