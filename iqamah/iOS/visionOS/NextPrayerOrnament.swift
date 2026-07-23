#if os(visionOS)
    import Combine
    import IqamahCore
    import SwiftUI

    // MARK: - Ornament root view (AC-0388–AC-0391)

    struct NextPrayerOrnament: View {
        @ObservedObject private var settings = SettingsManager.shared
        @StateObject private var timerState = OrnamentTimerState()

        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: timerState.prayerIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.appGold)

                Text(timerState.prayerLabel)
                    .font(.system(size: 15, weight: .semibold))

                Text(timerState.countdownString)
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ornamentCountdown")

                if !timerState.hijriDate.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, -6)
                    Text(timerState.hijriDate)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .glassBackgroundEffect()
            .onAppear { timerState.start(settings: settings) }
            .onDisappear { timerState.stop() }
        }
    }

    // MARK: - 1-second countdown + fasting relabel

    @MainActor
    private final class OrnamentTimerState: ObservableObject {
        @Published var prayerLabel: String = "—"
        @Published var prayerIcon: String = "star.and.crescent"
        @Published var countdownString: String = "—"
        @Published var hijriDate: String = ""

        private var cancellable: (any Cancellable)?

        func start(settings: SettingsManager) {
            recalculate(settings: settings)
            cancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in self?.recalculate(settings: settings) }
        }

        func stop() {
            cancellable?.cancel()
            cancellable = nil
        }

        private func recalculate(settings: SettingsManager) {
            guard let city = settings.loadCity(),
                  let tz = TimeZone(identifier: city.timezone),
                  let times = try? PrayerCalculator(
                      coordinate: city.coordinate,
                      timezone: tz,
                      method: settings.calculationMethod,
                      asrMethod: settings.asrMethod
                  ).calculate(for: Date())
            else { return }

            let hijriFmt = DateFormatter()
            hijriFmt.calendar = Calendar(identifier: .islamicUmmAlQura)
            hijriFmt.dateFormat = "d MMMM"
            hijriDate = hijriFmt.string(from: Date())

            let now = Date()
            let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
            let rawTimes: [String: Date] = [
                "Fajr": times.fajr, "Dhuhr": times.dhuhr,
                "Asr": times.asr, "Maghrib": times.maghrib, "Isha": times.isha,
            ]

            let adjusted: [(String, Date)] = prayerNames.compactMap { name in
                guard let t = rawTimes[name] else { return nil }
                let adj = settings.getAdjustment(for: name)
                return (name, Calendar.current.date(byAdding: .minute, value: adj, to: t) ?? t)
            }

            guard let next = adjusted.first(where: { $0.1 > now }) else {
                prayerLabel = "—"; prayerIcon = "star.and.crescent"; countdownString = "—"
                return
            }

            let fastingState = FastingModeEngine.evaluate(
                for: now,
                settings: settings.fastingModeSettings,
                calculationMethod: settings.calculationMethod,
                hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
                timezone: tz
            )
            prayerLabel = FastingLabelFormatter.relabel(
                prayerName: next.0,
                prayerTime: next.1,
                currentTime: now,
                state: fastingState
            )
            prayerIcon = Self.icon(for: next.0)

            let diff = Int(next.1.timeIntervalSince(now))
            let h = diff / 3600, m = (diff % 3600) / 60, s = diff % 60
            countdownString = h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
        }

        private static func icon(for prayer: String) -> String {
            switch prayer {
            case "Fajr": "moon.stars.fill"
            case "Dhuhr": "sun.max.fill"
            case "Asr": "sun.min.fill"
            case "Maghrib": "sunset.fill"
            case "Isha": "moon.fill"
            default: "star.and.crescent"
            }
        }
    }
#endif
