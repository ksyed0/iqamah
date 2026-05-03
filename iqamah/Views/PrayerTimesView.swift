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
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)

                Text("Iqamah")
                    .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.76, blue: 0.06),
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
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Date display — Gregorian only, now cleaner
            Text(currentDate.formattedGregorianDate())
                .font(.subheadline.bold())
                .padding(.vertical, 12)

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
        .background(Color(nsColor: .windowBackgroundColor))
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
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var player = AdhaaanPlayer.shared

    private var timeFormatter: DateFormatter {
        PrayerTimes.timeFormatter(for: timezone, use24Hour: settingsManager.use24HourTime)
    }

    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(prayerTimes.prayers.enumerated()), id: \.offset) { _, prayer in
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
                        onAdjust: { delta in adjustPrayerTime(for: prayer.name, delta: delta) }
                    )
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
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
                    .font(.callout)
                    .foregroundColor(.secondary) // AC-0063: no opacity reduction on semantic colour
                    .frame(width: 44, height: 36)
                Text("Sunrise")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatter.string(from: time))
                .font(.callout)
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

// MARK: - Prayer Time Row

struct PrayerTimeRow: View {
    let name: String
    let time: Date
    let formatter: DateFormatter
    let adjustment: Int
    @Binding var selectedAdhaan: Adhaan
    @Binding var isPrayerMuted: Bool
    let isHighlighted: Bool
    let onAdjust: (Int) -> Void

    @State private var isHovering = false
    @ObservedObject private var player = AdhaaanPlayer.shared

    private var adhaanOptions: [Adhaan] {
        name == "Fajr" ? Adhaan.availableForFajr : Adhaan.available
    }

    // Gold accent colour matching app brand
    private let gold = Color(red: 0.88, green: 0.69, blue: 0.06)

    var body: some View {
        VStack(spacing: 0) { // outer VStack — holds row + adhaan picker
            HStack(spacing: 0) {
                // ── Left accent stripe (highlighted only) ───────────────────
                Rectangle()
                    .fill(isHighlighted ? gold : Color.clear)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .padding(.vertical, 8)

                HStack(spacing: 16) {
                    // Prayer icon and name
                    HStack(spacing: 14) {
                        ZStack {
                            // Highlighted: filled gold circle; normal: subtle grey
                            Circle()
                                .fill(isHighlighted
                                    ? gold.opacity(0.20)
                                    : Color.secondary.opacity(0.08))
                                .frame(width: 44, height: 44)

                            Image(systemName: iconName)
                                .font(.title3.weight(.medium))
                                .foregroundColor(isHighlighted ? gold : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.body.bold())
                                .foregroundColor(isHighlighted ? gold : .primary)
                            // "NEXT" micro-label — unambiguous for first-time users
                            if isHighlighted {
                                Text("NEXT")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(gold.opacity(0.85))
                                    .tracking(1.2)
                            }
                        }
                    }

                    Spacer()

                    // Time display — larger when highlighted
                    Text(formatter.string(from: time))
                        .font(isHighlighted ? .title2.weight(.semibold) : .title3.weight(.medium))
                        .foregroundColor(isHighlighted ? gold : .primary)
                        .monospacedDigit()
                        .frame(minWidth: 100, alignment: .trailing)

                    // Adjustment badge — AC-0063: white-on-coloured-capsule ensures 4.5:1+ contrast
                    // AC-0065: pill shape + number together convey adjustment, not colour alone
                    if adjustment != 0 {
                        Text(adjustment > 0 ? "+\(adjustment)" : "\(adjustment)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(nsColor: NSColor(name: nil) { ap in
                                    // Dark red on light bg: #B01A10 ≈ 7:1 vs white
                                    // System red on dark bg: good contrast vs dark surface
                                    ap.bestMatch(from: [.darkAqua]) == .darkAqua
                                        ? .systemRed
                                        : NSColor(red: 0.69, green: 0.10, blue: 0.06, alpha: 1)
                                }))
                            )
                            .frame(minWidth: 35, alignment: .center)
                            .accessibilityLabel("\(abs(adjustment)) minute adjustment")
                    } else {
                        Color.clear.frame(width: 35)
                    }

                    // Adjustment controls
                    HStack(spacing: 6) {
                        Button(action: { onAdjust(-1) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .help("Decrease time by 1 minute")
                        .accessibilityLabel("Decrease \(name) time by 1 minute")
                        .accessibilityHint("Current adjustment: \(adjustment) minutes")

                        Button(action: { onAdjust(1) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .help("Increase time by 1 minute")
                        .accessibilityLabel("Increase \(name) time by 1 minute")
                        .accessibilityHint("Current adjustment: \(adjustment) minutes")
                    }
                    .opacity(isHovering ? 1.0 : 0.7)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Time adjustment controls for \(name)")

                    // Per-prayer mute toggle
                    // Direct assignment required: @Binding<Bool>.toggle() does not reliably fire the setter in Button action closures
                    // swiftlint:disable:next toggle_bool
                    Button(action: { isPrayerMuted = !isPrayerMuted }) {
                        Image(systemName: isPrayerMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.callout)
                            .foregroundColor(isPrayerMuted ? .orange : .secondary)
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
            } // end inner HStack

            // ── Adhaan picker — visible on hover or when a non-silent adhaan is set ──
            if isHovering || selectedAdhaan.id != "silent" {
                HStack(spacing: 10) {
                    // Context icon: muted if global OR per-prayer mute is active
                    Image(systemName: (player.isMuted || isPrayerMuted) ? "speaker.slash" : "music.note")
                        .font(.caption)
                        .foregroundColor((player.isMuted || isPrayerMuted) ? .orange.opacity(0.7) : .secondary)

                    Picker("Adhaan", selection: $selectedAdhaan) {
                        ForEach(adhaanOptions) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.mini)
                    .frame(maxWidth: 140)

                    // Preview play/stop toggle — works even when globally muted
                    if selectedAdhaan.id != "silent" {
                        Button(action: {
                            if player.isPlaying {
                                AdhaaanPlayer.shared.stop()
                            } else {
                                AdhaaanPlayer.shared.preview(selectedAdhaan)
                            }
                        }) {
                            Image(systemName: player.isPlaying ? "stop.circle.fill" : "play.circle")
                                .font(.caption)
                                .foregroundColor(player.isPlaying ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(player.isPlaying ? "Stop preview" : "Preview \(selectedAdhaan.displayName)")
                    }

                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        } // end outer VStack — wrap body in VStack for picker row
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted
                    ? gold.opacity(0.10)
                    : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHighlighted ? gold.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .shadow(
            color: isHighlighted ? gold.opacity(0.12) : .clear,
            radius: 6, x: 0, y: 2
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(name) prayer at \(formatter.string(from: time))\(adjustment != 0 ? ", adjusted by \(adjustment) minutes" : "")\(isPrayerMuted ? ", adhaan muted" : "")\(isHighlighted ? ", next prayer" : "")"
        )
    }

    private var iconName: String {
        switch name {
        case "Fajr":
            "sun.horizon.fill"
        case "Sunrise":
            "sunrise.fill"
        case "Dhuhr":
            "sun.max.fill"
        case "Asr":
            "sun.min.fill"
        case "Maghrib":
            "sunset.fill"
        case "Isha":
            "moon.stars.fill"
        default:
            "clock.fill"
        }
    }
}

// MARK: - Secondary toolbar button

/// Flat toolbar-style button used in the secondary bar below the primary header.
/// Matches macOS convention: no border, subtle background on hover only.
private struct SecondaryToolbarButton: View {
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
                        ? Color(nsColor: .quaternaryLabelColor).opacity(0.5)
                        : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
