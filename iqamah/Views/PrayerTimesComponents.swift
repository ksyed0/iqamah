// swiftlint:disable file_length type_body_length
import IqamahCore
import SwiftUI

// MARK: - Prayer Row Identifier

/// Identifies a unique row across two columns; `dayOffset` 0=today, 1=tomorrow.
struct PrayerRowID: Hashable {
    let dayOffset: Int
    let name: String
}

// MARK: - Prayer Times Table

/// Public so snapshot tests can reach it without @testable import.
public struct PrayerTimesTable: View {
    public let prayerTimes: PrayerTimes
    public let timezone: TimeZone
    /// 0 = today, 1 = tomorrow. Used in iPad landscape two-column layout.
    var dayOffset: Int = 0
    /// Shared across columns in iPad landscape so only one row is open at a time.
    @Binding var expandedRowID: PrayerRowID?
    /// Passed from parent's 60 s timer — forces re-render so NEXT badge advances.
    var now: Date = Date()

    @State private var adjustments: [String: Int] = [:]
    @State private var adhaanSelections: [String: Adhaan] = [:]
    @State private var prayerMuted: [String: Bool] = [:]
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var player = AdhaaanPlayer.shared

    /// Snapshot-test entry point — no shared expand state.
    public init(prayerTimes: PrayerTimes, timezone: TimeZone) {
        self.init(prayerTimes: prayerTimes, timezone: timezone, dayOffset: 0, expandedRowID: .constant(nil))
    }

    /// Full initialiser.
    init(prayerTimes: PrayerTimes, timezone: TimeZone, dayOffset: Int = 0,
         expandedRowID: Binding<PrayerRowID?> = .constant(nil), now: Date = Date()) {
        self.prayerTimes = prayerTimes; self.timezone = timezone
        self.dayOffset = dayOffset; _expandedRowID = expandedRowID; self.now = now
    }

    private var timeFormatter: DateFormatter {
        PrayerTimes.timeFormatter(for: timezone, use24Hour: settingsManager.use24HourTime)
    }

    public var body: some View {
        VStack(spacing: 1) {
            ForEach(prayerTimes.prayers, id: \.name) { prayer in
                let adjusted = adjustedTime(for: prayer)
                let rowID = PrayerRowID(dayOffset: dayOffset, name: prayer.name)

                #if os(iOS)
                    PrayerRowMobileView(
                        name: prayer.name,
                        time: adjusted,
                        formatter: timeFormatter,
                        isPast: adjusted < now,
                        isNext: isNextPrayer(adjustedTime: adjusted),
                        selectedAdhaan: adhaanSelections[prayer.name] ?? .silent,
                        isMuted: prayerMuted[prayer.name] ?? false,
                        isExpanded: expandedRowID == rowID,
                        onTap: {
                            withAnimation(.spring(duration: 0.25)) {
                                expandedRowID = expandedRowID == rowID ? nil : rowID
                            }
                        },
                        onSelectAdhaan: { adhaan in
                            adhaanSelections[prayer.name] = adhaan
                            settingsManager.setAdhaan(adhaan, for: prayer.name)
                            withAnimation(.spring(duration: 0.2)) { expandedRowID = nil }
                        },
                        onToggleMute: {
                            let muted = !(prayerMuted[prayer.name] ?? false)
                            prayerMuted[prayer.name] = muted
                            settingsManager.setPrayerMuted(muted, for: prayer.name)
                            withAnimation(.spring(duration: 0.2)) { expandedRowID = nil }
                        }
                    )
                #else
                    let isSunrise = prayer.name == "Sunrise"
                    if isSunrise {
                        SunriseRow(
                            time: adjusted,
                            formatter: timeFormatter,
                            selectedAlert: Binding(
                                get: { adhaanSelections["Sunrise"] ?? .silent },
                                set: { alert in
                                    adhaanSelections["Sunrise"] = alert
                                    settingsManager.setAdhaan(alert, for: "Sunrise")
                                }
                            )
                        )
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
                            isPickerExpanded: expandedRowID == rowID,
                            onTogglePicker: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    expandedRowID = expandedRowID == rowID ? nil : rowID
                                }
                            },
                            onAdjust: { delta in adjustPrayerTime(for: prayer.name, delta: delta) }
                        )
                    }
                #endif
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

    // BUG-0015: use `now` (parent timer) so NEXT badge advances automatically.
    private func isNextPrayer(adjustedTime: Date) -> Bool {
        for prayer in prayerTimes.prayers {
            guard prayer.name != "Sunrise" else { continue } // Sunrise is not a prayer
            let adj = self.adjustedTime(for: prayer)
            if adj > now {
                return adj == adjustedTime
            }
        }
        return adjustedTime == self.adjustedTime(for: (name: "Fajr", time: prayerTimes.fajr))
    }
}

// MARK: - Sunrise Row (US-0028)

/// Sunrise row — shows time and an alert-tone picker (no adhaan, no adjustments).
struct SunriseRow: View {
    let time: Date
    let formatter: DateFormatter
    @Binding var selectedAlert: Adhaan

    @State private var isPickerExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    private var gold: Color { colorScheme == .dark ? .appGold : .appGoldDark }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "sunrise.fill")
                        .font(.body)
                        .foregroundColor(.secondary)
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
                    .frame(minWidth: 72, alignment: .trailing)

                // Divider matching prayer rows
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 10)

                // Alert tone pill button
                Button(action: { isPickerExpanded.toggle() }) {
                    HStack(spacing: 3) {
                        Text(selectedAlert.id == "silent" ? "No alert" : selectedAlert.shortName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(selectedAlert.id == "silent"
                                ? Color.orange.opacity(0.55)
                                : Color.orange)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.orange.opacity(selectedAlert.id == "silent" ? 0.07 : 0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.22), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .frame(width: 100)
                .accessibilityLabel(selectedAlert.id == "silent"
                    ? "No alert for Sunrise. Tap to set."
                    : "Alert for Sunrise: \(selectedAlert.displayName). Tap to change.")

                // Mute placeholder (keeps alignment with prayer rows)
                Color.clear.frame(width: 36)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if isPickerExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alert tone")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .padding(.leading, 80)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Adhaan.availableForSunrise) { alert in
                                let isSel = selectedAlert.id == alert.id
                                Button(action: {
                                    selectedAlert = alert
                                    isPickerExpanded = false
                                }) {
                                    Text(alert.id == "silent" ? "No alert" : alert.shortName)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(isSel ? .white : Color.orange)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Capsule().fill(isSel
                                                ? Color.orange : Color.orange.opacity(0.08)))
                                        .overlay(Capsule().strokeBorder(
                                            Color.orange.opacity(isSel ? 0 : 0.25), lineWidth: 0.5
                                        ))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 80)
                        .padding(.trailing, 20)
                    }
                }
                .padding(.bottom, 8)
            }
        }
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

// MARK: - Prayer Time Row

struct PrayerTimeRow: View {
    let name: String
    let time: Date
    let formatter: DateFormatter
    let adjustment: Int
    @Binding var selectedAdhaan: Adhaan
    @Binding var isPrayerMuted: Bool
    let isHighlighted: Bool
    let isPickerExpanded: Bool
    let onTogglePicker: () -> Void
    let onAdjust: (Int) -> Void

    @ObservedObject private var player = AdhaaanPlayer.shared
    @Environment(\.colorScheme) private var colorScheme

    private var adhaanOptions: [Adhaan] {
        name == "Fajr" ? Adhaan.availableForFajr : Adhaan.available
    }

    private var effectiveGold: Color {
        colorScheme == .dark ? .appGold : .appGoldDark
    }

    private var accessibilityDescription: String {
        var parts = ["\(name) at \(formatter.string(from: time))"]
        if adjustment != 0 {
            parts.append("adjusted \(adjustment) min")
        }
        if isPrayerMuted {
            parts.append("muted")
        }
        if isHighlighted {
            parts.append("next prayer")
        }
        return parts.joined(separator: ", ")
    }

    // @ViewBuilder if/else avoids ternary type ambiguity between Color and Material
    @ViewBuilder private var rowBackground: some View {
        if isHighlighted {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(effectiveGold.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(effectiveGold.opacity(0.25), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }

    // Extracted to keep body under the Swift type-checker expression limit
    private var adhaanColumnButton: some View {
        Button(action: onTogglePicker) {
            HStack(spacing: 3) {
                Text(selectedAdhaan.id == "silent" ? "No adhaan" : selectedAdhaan.shortName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(selectedAdhaan.id == "silent"
                        ? Color.secondary.opacity(0.5)
                        : (isPrayerMuted
                            ? Color.secondary.opacity(0.4)
                            : effectiveGold.opacity(0.85)))
                    .lineLimit(1)
                    .strikethrough(
                        isPrayerMuted && selectedAdhaan.id != "silent",
                        color: Color.secondary.opacity(0.5)
                    )
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selectedAdhaan.id == "silent"
                        ? Color.secondary.opacity(0.07)
                        : (isPrayerMuted
                            ? Color.secondary.opacity(0.05)
                            : effectiveGold.opacity(colorScheme == .dark ? 0.10 : 0.12)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        selectedAdhaan.id == "silent"
                            ? Color.secondary.opacity(0.15)
                            : (isPrayerMuted
                                ? Color.secondary.opacity(0.10)
                                : effectiveGold.opacity(0.22)),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .help(selectedAdhaan.id == "silent"
            ? "Tap to set adhaan for \(name)"
            : "Adhaan: \(selectedAdhaan.displayName) — tap to change")
        .accessibilityLabel(selectedAdhaan.id == "silent"
            ? "No adhaan set for \(name). Tap to set."
            : "Adhaan for \(name): \(selectedAdhaan.displayName). Tap to change.")
        // XCUITest identifier (AC-0323, US-0066)
        .accessibilityIdentifier("adhaanPill-\(name)")
    }

    private var mainRowContent: some View {
        HStack(spacing: 0) {
            // Left accent stripe
            Rectangle()
                .fill(isHighlighted ? effectiveGold : Color.clear)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.vertical, 8)

            HStack(spacing: 0) {
                // Icon + name
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isHighlighted
                                ? effectiveGold.opacity(0.20)
                                : Color.secondary.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: iconName)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(isHighlighted ? effectiveGold : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.body.bold())
                            .foregroundStyle(isHighlighted ? effectiveGold : .primary)
                        if isHighlighted {
                            Text("NEXT")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(effectiveGold.opacity(0.85))
                                .tracking(1.2)
                        }
                    }
                }
                .padding(.leading, 16)

                Spacer()

                // Time + ± controls grouped together
                HStack(spacing: 8) {
                    Text(formatter.string(from: time))
                        .font(isHighlighted ? .title2.weight(.semibold) : .title3.weight(.medium))
                        .foregroundStyle(isHighlighted ? effectiveGold : .primary)
                        .monospacedDigit()
                        .frame(minWidth: 72, alignment: .trailing)
                        .overlay(alignment: .topTrailing) {
                            if adjustment != 0 {
                                Text(adjustment > 0 ? "+\(adjustment)" : "\(adjustment)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.red.opacity(0.8)))
                                    .offset(x: 4, y: -4)
                                    .accessibilityLabel("\(abs(adjustment)) minute adjustment")
                            }
                        }

                    HStack(spacing: 6) {
                        Button(action: { onAdjust(-1) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .help("Decrease \(name) by 1 minute")
                        .accessibilityLabel("Decrease \(name) time by 1 minute")
                        .accessibilityHint("Current adjustment: \(adjustment) minutes")

                        Button(action: { onAdjust(1) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .help("Increase \(name) by 1 minute")
                        .accessibilityLabel("Increase \(name) time by 1 minute")
                        .accessibilityHint("Current adjustment: \(adjustment) minutes")
                    }
                }
                .padding(.trailing, 8)

                // Divider between time/± and adhaan column
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 10)

                // Adhaan pill — always visible, fixed column
                adhaanColumnButton
                    .frame(width: 100)

                // Mute toggle — fixed column
                Button(action: { isPrayerMuted.toggle() }) {
                    Image(systemName: isPrayerMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.callout)
                        .foregroundStyle(isPrayerMuted ? .orange : .secondary)
                        .symbolRenderingMode(.hierarchical)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isPrayerMuted ? "Unmute \(name) adhaan" : "Mute \(name) adhaan")
                .accessibilityLabel(isPrayerMuted ? "Unmute \(name) adhaan" : "Mute \(name) adhaan")
                .opacity(player.isMuted ? 0.4 : 1.0)
                .frame(width: 36)
                .padding(.trailing, 16)
            }
            .padding(.vertical, isHighlighted ? 18 : 14)
        }
    }

    @ViewBuilder private var chipPickerSection: some View {
        if isPickerExpanded {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: (player.isMuted || isPrayerMuted) ? "speaker.slash" : "music.note")
                        .font(.caption)
                        .foregroundStyle((player.isMuted || isPrayerMuted)
                            ? Color.orange.opacity(0.7) : .secondary)
                    Text("Select adhaan for \(name)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if selectedAdhaan.id != "silent", player.isPlaying {
                        Button(action: { AdhaaanPlayer.shared.stop() }) {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(adhaanOptions) { option in
                            Button(action: {
                                selectedAdhaan = option
                                if option.id != "silent" {
                                    AdhaaanPlayer.shared.preview(option)
                                } else {
                                    onTogglePicker()
                                }
                            }) {
                                Text(option.displayName)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(selectedAdhaan.id == option.id
                                                ? effectiveGold.opacity(colorScheme == .dark ? 0.18 : 0.15)
                                                : Color.secondary.opacity(0.08))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(selectedAdhaan.id == option.id
                                                ? effectiveGold.opacity(0.35)
                                                : Color.clear, lineWidth: 1)
                                    )
                                    .foregroundStyle(selectedAdhaan.id == option.id
                                        ? effectiveGold : .secondary)
                            }
                            .buttonStyle(.plain)
                            // XCUITest identifier (AC-0323, US-0066)
                            .accessibilityIdentifier("adhaanOption-\(option.id)")
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .scrollIndicators(.visible)
            }
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            mainRowContent
            chipPickerSection
        }
        .background { rowBackground }
        .contentShape(Rectangle())
        .onKeyPress(.escape) {
            if isPickerExpanded {
                onTogglePicker()
            }
            return isPickerExpanded ? .handled : .ignored
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
    }

    private var iconName: String {
        switch name {
        case "Fajr": "sun.horizon.fill"
        case "Sunrise": "sunrise.fill"
        case "Dhuhr": "sun.max.fill"
        case "Asr": "sun.min.fill"
        case "Maghrib": "sunset.fill"
        case "Isha": "moon.stars.fill"
        default: "clock.fill"
        }
    }
}

// MARK: - Sunnah Section (ENH-0008)

/// Collapsible disclosure section showing Tahajjud and Duha prayer windows.
struct SunnahSection: View {
    let sunnahTimes: SunnahTimes
    let formatter: DateFormatter

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Sunnah Times")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Sunnah Times, expanded. Tap to collapse." : "Sunnah Times, collapsed. Tap to expand.")

            if isExpanded {
                VStack(spacing: 6) {
                    SunnahRow(
                        name: "Tahajjud",
                        subtitle: "Night Prayer",
                        icon: "moon.zzz.fill",
                        iconColor: Color.indigo,
                        start: sunnahTimes.tahajjudStart,
                        end: sunnahTimes.tahajjudEnd,
                        formatter: formatter
                    )
                    SunnahRow(
                        name: "Duha",
                        subtitle: "Morning Prayer",
                        icon: "sun.haze.fill",
                        iconColor: Color.orange,
                        start: sunnahTimes.duhaStart,
                        end: sunnahTimes.duhaEnd,
                        formatter: formatter
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct SunnahRow: View {
    let name: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let start: Date
    let end: Date
    let formatter: DateFormatter

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(iconColor.opacity(0.80))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(formatter.string(from: start)) – \(formatter.string(from: end))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(subtitle). Window: \(formatter.string(from: start)) to \(formatter.string(from: end))")
    }
}
