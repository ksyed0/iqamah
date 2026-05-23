import IqamahCore
import SwiftUI
import WidgetKit

struct InlineWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        let labeledName = displayedPrayerName(
            entry.nextPrayerName,
            prayerTime: entry.nextPrayerTime,
            referenceDate: entry.date,
            fastingActive: entry.fastingActive,
            fastingTriggerRaw: entry.fastingTriggerRaw
        )
        Label {
            Text("\(labeledName) at \(entry.nextPrayerTime.formatted(.dateTime.hour().minute()))")
        } icon: {
            Image(systemName: "clock")
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
