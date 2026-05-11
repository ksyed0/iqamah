import IqamahCore
import SwiftUI
import WidgetKit

struct InlineWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        Label {
            Text("\(entry.nextPrayerName) at \(entry.nextPrayerTime.formatted(.dateTime.hour().minute()))")
        } icon: {
            Image(systemName: "clock")
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
