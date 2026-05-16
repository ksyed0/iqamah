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
                if isRegular, isLandscape {
                    iPadLandscapeBody
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

        private var primaryHeader: some View {
            HStack(spacing: 12) {
                if let uiImg = UIImage(named: "AppIcon") {
                    Image(uiImage: uiImg)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)
                }
                Text("Iqamah")
                    .font(.system(size: titleFontSize, weight: .bold, design: .serif))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.appGoldDim, Color(red: 0.85, green: 0.65, blue: 0.13)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
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

        private var secondaryToolbarAboutOnly: some View {
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

    private var macOSBody: some View {
        VStack(spacing: 0) {
            // ── Primary header: brand + location + mute only ─────────
            HStack(spacing: 12) {
                #if os(macOS)
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.primary.opacity(0.10), radius: 3, x: 0, y: 1)
                #endif

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

                Button("Hilal Watch ›") {
                    openHilalWatch()
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appGold)
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
            expandedRowID = nil
            currentDate = newDate
            calculatePrayerTimes()
            calculateTomorrowPrayerTimes()
        } else {
            currentDate = newDate
        }

        #if os(iOS)
            // Mirror macOS AppDelegate.triggerAdhaanIfNeeded: play the selected adhaan
            // when a prayer time arrives while the app is in the foreground.
            triggerAdhaanIfNeeded(now: newDate)
        #endif
    }
}

// MARK: - PrayerTimesView+AdhaanTrigger (iOS only)

#if os(iOS)
    private extension PrayerTimesView {
        /// Set of "PrayerName-yyyy-MM-dd" keys already played today; reset at midnight.
        static var announcedPrayers: Set<String> = []
        static var announcedDate: Date = Date()

        func triggerAdhaanIfNeeded(now: Date) {
            guard let times = prayerTimes else { return }
            let calendar = Calendar.current
            if !calendar.isDate(now, inSameDayAs: Self.announcedDate) {
                Self.announcedPrayers.removeAll()
                Self.announcedDate = now
            }
            let tz = TimeZone(identifier: city.timezone) ?? .current
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; fmt.timeZone = tz
            for prayer in times.prayers where prayer.name != "Sunrise" {
                let adj = settingsStore.getAdjustment(for: prayer.name)
                let adjusted = calendar.date(byAdding: .minute, value: adj, to: prayer.time) ?? prayer.time
                let elapsed = now.timeIntervalSince(adjusted)
                guard elapsed >= 0, elapsed < 90 else { continue }
                let key = "\(prayer.name)-\(fmt.string(from: now))"
                guard !Self.announcedPrayers.contains(key) else { continue }
                Self.announcedPrayers.insert(key)
                guard !settingsStore.isPrayerMuted(prayer.name) else { continue }
                let adhaan = settingsStore.getAdhaan(for: prayer.name)
                guard adhaan.id != "silent" else { continue }
                AdhaaanPlayer.shared.play(adhaan)
            }
        }
    }
#endif

// MARK: - PrayerTimesView+iPad Landscape

#if os(iOS)
    private extension PrayerTimesView {
        @ViewBuilder
        var iPadLandscapeBody: some View {
            let tz = TimeZone(identifier: city.timezone) ?? .current
            VStack(spacing: 0) {
                // Full-width landscape header
                HStack(spacing: 16) {
                    Image("AppIcon").resizable().frame(width: 36, height: 36)
                        .shadow(color: Color.primary.opacity(0.10), radius: 2)
                    Text("Iqamah")
                        .font(.system(size: min(titleFontSize, 20), weight: .bold, design: .serif))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.appGoldDim, Color(red: 0.85, green: 0.65, blue: 0.13)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(city.name)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(calculationMethod.shortName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 150)
                    Spacer()
                    // Moon + Hijri + Hilal Watch button grouped together
                    HStack(spacing: 8) {
                        MoonPhaseView(phase: currentMoonPhase, size: 32)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(hijriDateLabel)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(moonPhaseSubtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: 140)
                        Button(action: openHilalWatch) {
                            Text("Hilal Watch ›")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appGoldDim)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(Color.appGoldDim.opacity(0.10)))
                        }
                        .buttonStyle(.plain)
                    }
                    if let nextTime = nextPrayerTime {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(nextTime, style: .timer)
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(Color.appGoldDim)
                                .accessibilityLabel("Time until next prayer")
                            Text("until next").font(.caption2).foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    Button(action: { AdhaaanPlayer.shared.toggleMute() }) {
                        Image(systemName: AdhaaanPlayer.shared.isMuted
                            ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.body)
                            .foregroundColor(AdhaaanPlayer.shared.isMuted ? .secondary : .accentColor)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background { Rectangle().fill(.ultraThinMaterial) }

                // Two columns: today | tomorrow
                HStack(alignment: .top, spacing: 0) {
                    // Today
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader("Today · \(currentDate.formattedGregorianDate())")
                            if let times = prayerTimes {
                                PrayerTimesTable(
                                    prayerTimes: times,
                                    timezone: tz,
                                    dayOffset: 0,
                                    expandedRowID: $expandedRowID
                                )
                                .padding(.horizontal, 12).padding(.bottom, 12)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    // Tomorrow
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            let tomorrow = Calendar.current.date(
                                byAdding: .day, value: 1, to: currentDate
                            ) ?? currentDate
                            sectionHeader("Tomorrow · \(tomorrow.formattedGregorianDate())")
                            if let times = tomorrowPrayerTimes {
                                PrayerTimesTable(
                                    prayerTimes: times,
                                    timezone: tz,
                                    dayOffset: 1,
                                    expandedRowID: $expandedRowID
                                )
                                .padding(.horizontal, 12).padding(.bottom, 12)
                            } else {
                                ProgressView().padding(.vertical, 20)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        func sectionHeader(_ text: String) -> some View {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
        }
    }
#endif
