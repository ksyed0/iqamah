import IqamahCore
import SwiftUI

/// Hero card shown above the prayer list on iPhone and iPad portrait.
/// Displays the current moon phase, Hijri date, countdown to next prayer,
/// and a Hilal Watch entry button.
struct PrayerHeroCard: View {
    let moonPhase: Double
    let hijriDateLabel: String
    let moonPhaseSubtitle: String
    let isHilalWatchEvening: Bool
    let nextPrayerTime: Date?
    let onHilalWatch: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var gold: Color { colorScheme == .dark ? .appGold : .appGoldDark }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MoonPhaseView(phase: moonPhase, size: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(hijriDateLabel)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(isHilalWatchEvening ? "Hilal Watch tonight" : moonPhaseSubtitle)
                    .font(.caption)
                    .foregroundStyle(isHilalWatchEvening ? Color.orange : Color.secondary)

                Button(action: onHilalWatch) {
                    Text("Hilal Watch ›")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(gold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Hilal Watch")
            }

            Spacer()

            if let nextTime = nextPrayerTime {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(nextTime, style: .timer)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(gold)
                        .multilineTextAlignment(.trailing)
                    Text("until next prayer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Time until next prayer")
                .accessibilityValue(Text(nextTime, style: .relative))
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
