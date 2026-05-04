import SwiftUI
import CoreLocation
import Combine

struct PrayerTimesView: View {
    let city: City
    let calculationMethod: CalculationMethod
    let asrMethod: AsrJuristicMethod
    let onSettingsSaved: (City, CalculationMethod, AsrJuristicMethod) -> Void

    @State private var currentDate = Date()
    @State private var prayerTimes: PrayerTimes?
    @State private var showQiblah = false
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var timerSubscription: Cancellable?
    @ObservedObject private var settingsStore = SettingsManager.shared

    // AC-0064: scale the serif title with the user's Dynamic Type size preference
    @ScaledMetric(relativeTo: .title3) private var titleFontSize: CGFloat = 20

    private let timer = Timer.publish(every: 60, on: .main, in: .common)

    var body: some View {
        VStack(spacing: 0) {
            // ── Primary header: brand + location + mute only ─────────
            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable()
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)

                Text("Iqamah")
                    .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.appGoldDim,
                                Color(red: 0.85, green: 0.65, blue: 0.13),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(calculationMethod.shortName)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Mute — the one action important enough for the primary header
                Button(action: { AdhaaanPlayer.shared.toggleMute() }) {
                    Image(systemName: AdhaaanPlayer.shared.isMuted
                        ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundColor(AdhaaanPlayer.shared.isMuted ? .secondary : .accentColor)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help(AdhaaanPlayer.shared.isMuted ? "Unmute Adhaan" : "Mute Adhaan")
                .accessibilityLabel(AdhaaanPlayer.shared.isMuted ? "Adhaan muted — tap to unmute" : "Adhaan on — tap to mute")
            }
            .padding(.horizontal, 22)
            .padding(.top, 46)
            .padding(.bottom, 10)
            .background {
                Rectangle().fill(.ultraThinMaterial)
            }

            // ── Secondary toolbar: navigation actions + Hijri date ───
            HStack(spacing: 0) {
                SecondaryToolbarButton(
                    label: "Qiblah",
                    systemImage: "location.north.line.fill",
                    action: { showQiblah = true }
                )
                .accessibilityLabel("Show Qiblah direction")

                SecondaryToolbarButton(
                    label: "Settings",
                    systemImage: "gearshape",
                    action: { showSettings = true }
                )
                .accessibilityLabel("Open settings")

                SecondaryToolbarButton(
                    label: "About",
                    systemImage: "info.circle",
                    action: { showAbout = true }
                )
                .accessibilityLabel("About Iqamah")

                Spacer()

                // Hijri date lives here — frees the date block below for Gregorian only
                Text(currentDate.formattedHijriDate())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 16)
            }
            .background {
                Rectangle().fill(.ultraThinMaterial)
            }

            Divider()

            // Date display — Gregorian only, now cleaner
            Text(currentDate.formattedGregorianDate())
                .font(.subheadline.bold())
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background {
                    Rectangle().fill(.ultraThinMaterial.opacity(0.6))
                }

            // Prayer times table
            if let prayerTimes {
                PrayerTimesTable(prayerTimes: prayerTimes, timezone: TimeZone(identifier: city.timezone) ?? .current)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            } else {
                ProgressView()
                    .padding(.vertical, 40)
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 640, idealHeight: 680)
        .sheet(isPresented: $showQiblah) {
            QiblahView(latitude: city.latitude, longitude: city.longitude, cityName: city.name)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(
                currentCity: city,
                currentMethod: calculationMethod,
                currentAsrMethod: asrMethod,
                onSave: { newCity, newMethod, newAsr in
                    showSettings = false
                    onSettingsSaved(newCity, newMethod, newAsr)
                },
                onCancel: { showSettings = false }
            )
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .onAppear {
            calculatePrayerTimes()
            timerSubscription = timer.connect()
        }
        .onDisappear {
            // Cancel timer to prevent memory leak
            timerSubscription?.cancel()
            timerSubscription = nil
        }
        .onReceive(timer) { _ in
            updateDate()
        }
    }

    private func calculatePrayerTimes() {
        let timezone = TimeZone(identifier: city.timezone) ?? .current
        let calculator = PrayerCalculator(
            coordinate: city.coordinate,
            timezone: timezone,
            method: calculationMethod,
            asrMethod: asrMethod
        )

        do {
            prayerTimes = try calculator.calculate(for: currentDate)
        } catch {
            // Log error and show user-friendly message
            print("Prayer calculation error: \(error.localizedDescription)")
            // In production, show alert to user
        }
    }

    private func updateDate() {
        let newDate = Date()
        let calendar = Calendar.current

        // Check if day has changed
        if !calendar.isDate(newDate, inSameDayAs: currentDate) {
            currentDate = newDate
            calculatePrayerTimes()
        } else {
            currentDate = newDate
        }
    }
}

struct PrayerTimesTable: View {
    let prayerTimes: PrayerTimes
    let timezone: TimeZone

    @State private var adjustments: [String: Int] = [:]
    @State private var adhaanSelections: [String: Adhaan] = [:]
    @State private var prayerMuted: [String: Bool] = [:]
    @State private var expandedPrayerName: String? = nil
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
        if adjustment != 0 { parts.append("adjusted \(adjustment) min") }
        if isPrayerMuted { parts.append("muted") }
        if isHighlighted { parts.append("next prayer") }
        return parts.joined(separator: ", ")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isHighlighted ? effectiveGold.opacity(0.10) : .ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? effectiveGold.opacity(0.25) : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
    }

    // Extracted to keep body under the Swift type-checker expression limit
    private var adhaanColumnButton: some View {
        Button(action: onTogglePicker) {
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(.caption2)
                    .foregroundStyle(selectedAdhaan.id == "silent"
                        ? Color.secondary.opacity(0.4)
                        : effectiveGold.opacity(0.75))
                if selectedAdhaan.id == "silent" {
                    Text("—")
                        .font(.caption.italic())
                        .foregroundStyle(.secondary.opacity(0.5))
                } else {
                    Text(selectedAdhaan.shortName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(effectiveGold.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(selectedAdhaan.id == "silent"
                        ? Color.clear
                        : effectiveGold.opacity(colorScheme == .dark ? 0.10 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(selectedAdhaan.id == "silent"
                        ? Color.clear
                        : effectiveGold.opacity(0.22), lineWidth: 0.5)
            )
            .frame(minWidth: 72, alignment: .center)
        }
        .buttonStyle(.plain)
        .help(selectedAdhaan.id == "silent"
            ? "Tap to set adhaan for \(name)"
            : "Adhaan: \(selectedAdhaan.displayName) — tap to change")
        .accessibilityLabel(selectedAdhaan.id == "silent"
            ? "No adhaan set for \(name). Tap to set."
            : "Adhaan for \(name): \(selectedAdhaan.displayName). Tap to change.")
    }

    private var mainRowContent: some View {
        HStack(spacing: 0) {
            // Left accent stripe (highlighted only)
            Rectangle()
                .fill(isHighlighted ? effectiveGold : Color.clear)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.vertical, 8)

            HStack(spacing: 16) {
                // Prayer icon + name
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

                Spacer()

                adhaanColumnButton

                // Time + optional adjustment badge
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

                // Adjustment controls
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

                // Per-prayer mute
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
            }
            .padding(.horizontal, 16)
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
                ScrollView(.horizontal, showsIndicators: false) {
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
                        }
                    }
                    .padding(.horizontal, 2)
                }
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
            if isPickerExpanded { onTogglePicker() }
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
