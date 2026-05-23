#if os(iOS)
    import IqamahCore
    import SwiftUI

    /// Hero card shown above the prayer list on iPhone and iPad portrait.
    /// Displays the current moon phase, Hijri date, countdown to next prayer,
    /// and a Hilal Watch entry button.
    ///
    /// When Fasting Mode is active (or today is hard-prohibited), a `FastingBanner`
    /// is rendered above the hero block. AC-0369 (iOS portion).
    struct PrayerHeroCard: View {
        let moonPhase: Double
        let hijriDateLabel: String
        let moonPhaseSubtitle: String
        let isHilalWatchEvening: Bool
        let nextPrayerTime: Date?
        let onHilalWatch: () -> Void
        // Fasting Mode inputs (optional — caller passes today's PrayerTimes + settings).
        let fastingPrayerTimes: PrayerTimes?
        let fastingSettings: FastingModeSettings?
        let fastingCalculationMethod: CalculationMethod?
        let fastingTimezone: TimeZone?

        init(
            moonPhase: Double,
            hijriDateLabel: String,
            moonPhaseSubtitle: String,
            isHilalWatchEvening: Bool,
            nextPrayerTime: Date?,
            onHilalWatch: @escaping () -> Void,
            fastingPrayerTimes: PrayerTimes? = nil,
            fastingSettings: FastingModeSettings? = nil,
            fastingCalculationMethod: CalculationMethod? = nil,
            fastingTimezone: TimeZone? = nil
        ) {
            self.moonPhase = moonPhase
            self.hijriDateLabel = hijriDateLabel
            self.moonPhaseSubtitle = moonPhaseSubtitle
            self.isHilalWatchEvening = isHilalWatchEvening
            self.nextPrayerTime = nextPrayerTime
            self.onHilalWatch = onHilalWatch
            self.fastingPrayerTimes = fastingPrayerTimes
            self.fastingSettings = fastingSettings
            self.fastingCalculationMethod = fastingCalculationMethod
            self.fastingTimezone = fastingTimezone
        }

        @Environment(\.colorScheme) private var colorScheme
        private var gold: Color { colorScheme == .dark ? .appGold : .appGoldDark }

        /// AC-0369 (iOS): evaluate today's Fasting Mode state when caller provided inputs.
        private var fastingState: FastingDayState? {
            guard let settings = fastingSettings,
                  let method = fastingCalculationMethod,
                  let tz = fastingTimezone else { return nil }
            return FastingModeEngine.evaluate(
                for: Date(),
                settings: settings,
                calculationMethod: method,
                hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
                timezone: tz
            )
        }

        var body: some View {
            VStack(spacing: 0) {
                if let state = fastingState,
                   state.isActive || state.prohibition != nil {
                    FastingBanner(
                        state: state,
                        fajrTime: fastingPrayerTimes?.fajr,
                        maghribTime: fastingPrayerTimes?.maghrib,
                        isShiaMethod: fastingCalculationMethod?.isShiaMethod ?? false
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                heroRow
            }
        }

        private var heroRow: some View {
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
                    // XCUITest identifier (AC-0331, US-0067)
                    .accessibilityIdentifier("hilalWatchButton")
                }

                Spacer()

                if let nextTime = nextPrayerTime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(nextTime, style: .timer)
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(gold)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Time until next prayer")
                        Text("until next prayer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
#endif
