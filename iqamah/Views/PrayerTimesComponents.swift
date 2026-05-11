import IqamahCore
import SwiftUI

// MARK: - Prayer Times Table

struct PrayerTimesTable: View {
    let prayerTimes: PrayerTimes
    let timezone: TimeZone

    @State private var adjustments: [String: Int] = [:]
    @State private var adhaanSelections: [String: Adhaan] = [:]
    @State private var prayerMuted: [String: Bool] = [:]
    @State private var expandedPrayerName: String?
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var player = AdhaaanPlayer.shared

    private var timeFormatter: DateFormatter {
        PrayerTimes.timeFormatter(for: timezone, use24Hour: settingsManager.use24HourTime)
    }

    var body: some View {
        VStack(spacing: 1) {
            ForEach(prayerTimes.prayers, id: \.name) { prayer in
                let isSunrise = prayer.name == "Sunrise"
                let adjusted = adjustedTime(for: prayer)
                if isSunrise {
                    SunriseRow(time: adjusted, formatter: timeFormatter)
                } else {
                    PrayerTimeRow(
                        name: prayer.name,
                        time: adjusted,
                        formatter: timeFormatter,
                        adjustment: adjustments[prayer.name] ?? 0,
                        selectedAdhaan: Binding(
                            get: { adhaanSelections[prayer.name] ?? .silent },
                            set: { newAdhaan in
                                adhaanSelections[prayer.name] = newAdhaan
                                settingsManager.setAdhaan(newAdhaan, for: prayer.name)
                            }
                        ),
                        isPrayerMuted: Binding(
                            get: { prayerMuted[prayer.name] ?? false },
                            set: { muted in
                                prayerMuted[prayer.name] = muted
                                settingsManager.setPrayerMuted(muted, for: prayer.name)
                            }
                        ),
                        isHighlighted: isNextPrayer(adjustedTime: adjusted),
                        isPickerExpanded: expandedPrayerName == prayer.name,
                        onTogglePicker: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                expandedPrayerName = expandedPrayerName == prayer.name ? nil : prayer.name
                            }
                        },
                        onAdjust: { delta in adjustPrayerTime(for: prayer.name, delta: delta) }
                    )
                }
            }
        }
        .onAppear { loadAdjustments() }

        // Reset button — only shown when at least one adjustment is non-zero
        if adjustments.values.contains(where: { $0 != 0 }) {
            HStack {
                Spacer()
                Button(action: resetAllAdjustments) {
                    Label("Reset adjustments", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all ± minute adjustments and return to calculated times")
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
    }

    private func loadAdjustments() {
        for prayer in prayerTimes.prayers {
            adjustments[prayer.name] = settingsManager.getAdjustment(for: prayer.name)
            adhaanSelections[prayer.name] = settingsManager.getAdhaan(for: prayer.name)
            prayerMuted[prayer.name] = settingsManager.isPrayerMuted(prayer.name)
        }
    }

    private func adjustedTime(for prayer: (name: String, time: Date)) -> Date {
        let adjustmentMinutes = adjustments[prayer.name] ?? 0
        return Calendar.current.date(byAdding: .minute, value: adjustmentMinutes, to: prayer.time) ?? prayer.time
    }

    private func resetAllAdjustments() {
        settingsManager.resetAdjustments()
        for prayer in prayerTimes.prayers {
            adjustments[prayer.name] = 0
        }
    }

    private func adjustPrayerTime(for prayerName: String, delta: Int) {
        let currentAdjustment = adjustments[prayerName] ?? 0
        let newAdjustment = currentAdjustment + delta
        adjustments[prayerName] = newAdjustment
        settingsManager.setAdjustment(newAdjustment, for: prayerName)
    }

    // BUG-0015: compare adjusted times so this matches the status bar highlight
    private func isNextPrayer(adjustedTime: Date) -> Bool {
        let now = Date()
        for prayer in prayerTimes.prayers {
            let adj = self.adjustedTime(for: prayer)
            if adj > now {
                return adj == adjustedTime
            }
        }
        return adjustedTime == self.adjustedTime(for: (name: "Fajr", time: prayerTimes.fajr))
    }
}

// MARK: - Sunrise Row (US-0028)

/// Muted info row for Sunrise — not a prayer, no adjustment controls.
struct SunriseRow: View {
    let time: Date
    let formatter: DateFormatter

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "sunrise.fill")
                    .font(.body)
                    .foregroundColor(.secondary) // AC-0063: no opacity reduction on semantic colour
                    .frame(width: 44, height: 36)
                Text("Sunrise")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatter.string(from: time))
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(minWidth: 100, alignment: .trailing)
            Color.clear.frame(width: 76)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sunrise at \(formatter.string(from: time))")
    }
}

// MARK: - Secondary Toolbar Button

/// Flat toolbar-style button used in the secondary bar below the primary header.
/// Matches macOS convention: no border, subtle background on hover only.
struct SecondaryToolbarButton: View {
    let label: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isHovering ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering
                        ? Color.secondary.opacity(0.15)
                        : Color.clear)
            )
        }
        .buttonStyle(.plain)
        #if os(macOS)
            .onHover { isHovering = $0 }
        #endif
    }
}
