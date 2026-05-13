import SwiftUI
import CoreLocation
import Combine
import IqamahCore

struct PrayerTimesView: View {
    let city: City
    let calculationMethod: CalculationMethod
    let asrMethod: AsrJuristicMethod
    let onSettingsSaved: (City, CalculationMethod, AsrJuristicMethod) -> Void

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var currentDate = Date()
    @State private var prayerTimes: PrayerTimes?
    @State private var tomorrowPrayerTimes: PrayerTimes? = nil
    @State private var showQiblah = false
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var timerSubscription: Cancellable?
    @State private var expandedRowID: PrayerRowID? = nil
    @ObservedObject private var settingsStore = SettingsManager.shared
    @ObservedObject private var player = AdhaaanPlayer.shared

    // AC-0064: scale the serif title with the user's Dynamic Type size preference
    @ScaledMetric(relativeTo: .title3) private var titleFontSize: CGFloat = 28

    private let timer = Timer.publish(every: 60, on: .main, in: .common)

    // MARK: - Body

    var body: some View {
        #if os(iOS)
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let isRegular = hSizeClass == .regular
            if isRegular && isLandscape {
                portraitBody // Task 6 will replace this with iPadLandscapeBody
            } else {
                portraitBody
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .onAppear {
            calculatePrayerTimes()
            calculateTomorrowPrayerTimes()
            timerSubscription = timer.connect()
        }
        .onDisappear { timerSubscription?.cancel(); timerSubscription = nil }
        .onReceive(timer) { _ in updateDate() }
        #else
        macOSBody
        #endif
    }

    // MARK: - iOS Portrait Layout

    #if os(iOS)
    @ViewBuilder
    private var portraitBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                primaryHeader
                secondaryToolbarAboutOnly
                if let times = prayerTimes {
                    let tz = TimeZone(identifier: city.timezone) ?? .current
                    PrayerHeroCard(
                        moonPhase: currentMoonPhase,
                        hijriDateLabel: hijriDateLabel,
                        moonPhaseSubtitle: moonPhaseSubtitle,
                        isHilalWatchEvening: isHilalWatchEvening,
                        nextPrayerTime: nextPrayerTime,
                        onHilalWatch: openHilalWatch
                    )
                    Text(currentDate.formattedGregorianDate())
                        .font(.subheadline.bold())
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.06))
                    PrayerTimesTable(
                        prayerTimes: times,
                        timezone: tz,
                        dayOffset: 0,
                        expandedRowID: $expandedRowID
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                } else {
                    ProgressView().padding(.vertical, 40)
                }
            }
        }
        .background(.regularMaterial)
    }

    @ViewBuilder private var primaryHeader: some View {
        HStack(spacing: 12) {
            Image("AppIcon")
                .resizable()
                .frame(width: 48, height: 48)
                .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)
            Text("Iqamah")
                .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                .foregroundStyle(LinearGradient(
                    colors: [Color.appGoldDim, Color(red: 0.85, green: 0.65, blue: 0.13)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(calculationMethod.shortName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { AdhaaanPlayer.shared.toggleMute() }) {
                Image(systemName: AdhaaanPlayer.shared.isMuted
                      ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundColor(AdhaaanPlayer.shared.isMuted ? .secondary : .accentColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background { Rectangle().fill(.ultraThinMaterial) }
    }

    @ViewBuilder private var secondaryToolbarAboutOnly: some View {
        HStack(spacing: 0) {
            SecondaryToolbarButton(
                label: "About",
                systemImage: "info.circle",
                action: { showAbout = true }
            )
            Spacer()
        }
        .background { Rectangle().fill(.ultraThinMaterial) }
    }
    #endif

    // MARK: - macOS Layout

    @ViewBuilder
    private var macOSBody: some View {
        VStack(spacing: 0) {
            // ── Primary header: brand + location + mute only ─────────
            HStack(spacing: 12) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 64, height: 64)
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
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(calculationMethod.shortName)
                        .font(.caption.weight(.medium))
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
            .padding(.top, 16)
            .padding(.bottom, 10)
            .background {
                Rectangle().fill(.ultraThinMaterial)
            }

            // ── Secondary toolbar: navigation actions + Hijri date ───
            // On iOS, Qiblah and Settings are in the tab bar — only About is unique here.
            HStack(spacing: 0) {
                #if os(macOS)
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
                    .keyboardShortcut(",", modifiers: .command)
                #endif

                SecondaryToolbarButton(
                    label: "About",
                    systemImage: "info.circle",
                    action: { showAbout = true }
                )
                .accessibilityLabel("About Iqamah")

                Spacer()
            }
            .background {
                Rectangle().fill(.ultraThinMaterial)
            }

            // Moon phase preview + Hilal Watch entry
            HStack(spacing: 12) {
                MoonPhaseView(phase: currentMoonPhase, size: 56)
                    .accessibilityLabel(moonPhaseAccessibilityLabel)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hijriDateLabel)
                        .font(.subheadline)
                    Text(isHilalWatchEvening ? "Hilal Watch tonight" : moonPhaseSubtitle)
                        .font(.caption)
                        .foregroundStyle(isHilalWatchEvening ? .orange : .secondary)
                }

                Spacer()

                Button("Details") {
                    openHilalWatch()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
    }

    // MARK: - Next Prayer Helpers (iOS)

    #if os(iOS)
    private var nextPrayerTime: Date? {
        prayerTimes?.prayers
            .first(where: { adjustedPrayerTime($0) > Date() && $0.name != "Sunrise" })
            .map { adjustedPrayerTime($0) }
    }

    private func adjustedPrayerTime(_ prayer: (name: String, time: Date)) -> Date {
        let adj = settingsStore.getAdjustment(for: prayer.name)
        return Calendar.current.date(byAdding: .minute, value: adj, to: prayer.time) ?? prayer.time
    }
    #endif

    // MARK: - Moon phase + Hijri computed properties

    private var currentMoonPhase: Double {
        // Synodic phase fraction 0–1
        let now = Date()
        let prev = NewMoon.previous(before: now)
        let elapsed = now.timeIntervalSince(prev)
        let synodicMonth = 29.530588 * 86400.0
        return (elapsed / synodicMonth).truncatingRemainder(dividingBy: 1.0)
    }

    private var isHilalWatchEvening: Bool {
        // True on the 29th or 30th day of the current Hijri month
        let cal = Calendar(identifier: .islamicUmmAlQura)
        let day = cal.component(.day, from: Date())
        return day == 29 || day == 30
    }

    private var moonPhaseSubtitle: String {
        let phase = currentMoonPhase
        switch phase {
        case 0 ..< 0.03: return "New Moon"
        case 0.03 ..< 0.25: return "Waxing Crescent"
        case 0.25 ..< 0.27: return "First Quarter"
        case 0.27 ..< 0.48: return "Waxing Gibbous"
        case 0.48 ..< 0.52: return "Full Moon"
        case 0.52 ..< 0.73: return "Waning Gibbous"
        case 0.73 ..< 0.75: return "Last Quarter"
        case 0.75 ..< 0.97: return "Waning Crescent"
        default: return "New Moon"
        }
    }

    private var moonPhaseAccessibilityLabel: String {
        "\(moonPhaseSubtitle), \(Int(currentMoonPhase * 29.5)) days old"
    }

    private var hijriDateLabel: String {
        let date = Date()
        let cal = Calendar(identifier: .islamicUmmAlQura)
        var comps = cal.dateComponents([.day, .month, .year], from: date)
        if let day = comps.day {
            comps.day = day + settingsStore.hijriDayOffset
        }
        let monthNames = ["Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
                          "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
                          "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"]
        let m = (comps.month ?? 1) - 1
        let monthName = m >= 0 && m < 12 ? monthNames[m] : ""
        return "\(comps.day ?? 1) \(monthName) \(comps.year ?? 1446) AH"
    }

    private func openHilalWatch() {
        NotificationCenter.default.post(name: .openHilalWatch, object: nil)
    }

    private func calculateTomorrowPrayerTimes() {
        let timezone = TimeZone(identifier: city.timezone) ?? .current
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        let calculator = PrayerCalculator(
            coordinate: city.coordinate,
            timezone: timezone,
            method: calculationMethod,
            asrMethod: asrMethod
        )
        tomorrowPrayerTimes = try? calculator.calculate(for: tomorrow)
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
            calculateTomorrowPrayerTimes()
        } else {
            currentDate = newDate
        }
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
