#if os(iOS)
    import IqamahCore
    import SwiftUI

    /// Compact prayer row for iOS: icon · name · adhaan pill · time.
    /// Tapping the row signals the parent to toggle the chip tray.
    /// `isPast` dims the row; `isNext` applies gold highlight.
    struct PrayerRowMobileView: View {
        let name: String
        let time: Date
        let formatter: DateFormatter
        let isPast: Bool
        let isNext: Bool
        let selectedAdhaan: Adhaan
        let isMuted: Bool
        let isExpanded: Bool
        let onTap: () -> Void
        let onSelectAdhaan: (Adhaan) -> Void
        let onToggleMute: () -> Void

        @Environment(\.colorScheme) private var colorScheme
        private var gold: Color { colorScheme == .dark ? .appGold : .appGoldDark }
        private var isSunrise: Bool { name == "Sunrise" }

        var body: some View {
            VStack(spacing: 0) {
                rowContent
                if isExpanded {
                    AdhaanChipTray(
                        prayerName: name,
                        selectedAdhaan: selectedAdhaan,
                        isMuted: isMuted,
                        onSelectAdhaan: onSelectAdhaan,
                        onToggleMute: onToggleMute
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }

        private var rowContent: some View {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(isNext ? gold.opacity(0.15) : Color.secondary.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: iconName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(isNext ? gold : .secondary)
                    }

                    // Prayer name
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(isNext ? .body.bold() : .body)
                            .foregroundStyle(isNext ? gold : .primary)
                        if isNext {
                            Text("NEXT")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(gold.opacity(0.85))
                                .tracking(1.0)
                        }
                    }

                    Spacer()

                    // Adhaan / alert pill (between name and time)
                    if isSunrise {
                        alertPill
                    } else {
                        adhaanPill
                    }

                    // Time
                    Text(formatter.string(from: time))
                        .font(isNext ? .body.bold() : .body)
                        .foregroundStyle(isNext ? gold : .primary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isPast ? 0.28 : 1.0)
            .background {
                if isNext {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(gold.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(gold.opacity(0.20), lineWidth: 1)
                        )
                }
            }
        }

        private var adhaanPill: some View {
            let isSet = selectedAdhaan.id != "silent"
            return Text(isSet ? selectedAdhaan.shortName : "No adhaan")
                .font(.caption.weight(.medium))
                .foregroundStyle(isSet ? gold : Color.secondary.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(isSet ? gold.opacity(0.12) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSet ? gold.opacity(0.30) : Color.secondary.opacity(0.15),
                                      lineWidth: 0.5)
                )
                .accessibilityLabel(isSet ? "Adhaan: \(selectedAdhaan.displayName). Tap to change." : "No adhaan set. Tap to set.")
        }

        private var alertPill: some View {
            let isSet = selectedAdhaan.id != "silent"
            return Text(isSet ? selectedAdhaan.shortName : "No alert")
                .font(.caption.weight(.medium))
                .foregroundStyle(isSet ? Color.orange : Color.orange.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange.opacity(0.08)))
                .overlay(Capsule().strokeBorder(Color.orange.opacity(0.20), lineWidth: 0.5))
                .accessibilityLabel(isSet ? "Alert: \(selectedAdhaan.displayName). Tap to change." : "No alert set. Tap to set.")
        }

        private var iconName: String {
            switch name {
            case "Fajr": "moon.stars.fill"
            case "Sunrise": "sunrise.fill"
            case "Dhuhr": "sun.max.fill"
            case "Asr": "sun.haze.fill"
            case "Maghrib": "sunset.fill"
            case "Isha": "moon.fill"
            default: "clock"
            }
        }
    }

    // MARK: - Adhaan Chip Tray

    /// Inline chip picker that expands below a prayer row.
    /// Standard prayers: alert tones + adhaan recordings + Mute.
    /// Sunrise: alert tones only, no adhaan recordings, no Mute.
    /// Fajr: alert tones + Fajr adhaan recordings + standard adhaan recordings.
    struct AdhaanChipTray: View {
        let prayerName: String
        let selectedAdhaan: Adhaan
        let isMuted: Bool
        let onSelectAdhaan: (Adhaan) -> Void
        let onToggleMute: () -> Void

        @Environment(\.colorScheme) private var colorScheme
        @ObservedObject private var player = AdhaaanPlayer.shared
        private var gold: Color { colorScheme == .dark ? .appGold : .appGoldDark }

        private var isSunrise: Bool { prayerName == "Sunrise" }

        /// Delegates to IqamahCore canonical lists so AdhaanChipTray stays in sync with
        /// Adhaan.availableForSunrise / availableForFajr / available automatically.
        private var allOptions: [Adhaan] {
            if isSunrise { return Adhaan.availableForSunrise }
            if prayerName == "Fajr" { return Adhaan.availableForFajr }
            return Adhaan.available
        }

        private var alertTones: [Adhaan] {
            allOptions.filter { $0.filename.hasPrefix("tone_") || $0.id == "silent" }
        }

        private var adhaanRecordings: [Adhaan] {
            allOptions.filter { !$0.filename.hasPrefix("tone_") && $0.id != "silent" }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Stop preview button — shown while a sound is playing
                if player.isPlaying {
                    Button(action: { player.stop() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .font(.caption)
                            Text("Stop preview")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(gold)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(gold.opacity(0.10)))
                        .overlay(Capsule().strokeBorder(gold.opacity(0.25), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }

                // Alert tones section
                chipSection(
                    label: "🔔 Alert tones",
                    chips: alertTones,
                    accent: .orange,
                    silentLabel: isSunrise ? "No alert" : "No adhaan"
                )

                // Adhaan recordings section (prayers only)
                if !adhaanRecordings.isEmpty {
                    chipSection(
                        label: "🕌 Adhaan",
                        chips: adhaanRecordings,
                        accent: gold,
                        silentLabel: nil
                    )

                    // Mute chip
                    Button(action: onToggleMute) {
                        Label(isMuted ? "Unmute" : "Mute",
                              systemImage: isMuted ? "speaker.slash.fill" : "speaker.slash")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(isMuted ? .white : Color.red.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(isMuted ? Color.red.opacity(0.8) : Color.red.opacity(0.08)))
                            .overlay(Capsule().strokeBorder(Color.red.opacity(isMuted ? 0 : 0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isMuted ? "Unmute this prayer" : "Mute this prayer")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }

        private func chipSection(
            label: String,
            chips: [Adhaan],
            accent: Color,
            silentLabel: String?
        ) -> some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78, maximum: 120))],
                          alignment: .leading, spacing: 5) {
                    ForEach(chips) { adhaan in
                        let isSelected = selectedAdhaan.id == adhaan.id
                        let displayName: String = {
                            if adhaan.id == "silent" { return silentLabel ?? "No adhaan" }
                            return adhaan.shortName
                        }()
                        Button(action: {
                            // Play a preview so the user can hear before committing.
                            // preview() ignores isMuted so it always sounds.
                            AdhaaanPlayer.shared.preview(adhaan)
                            onSelectAdhaan(adhaan)
                        }) {
                            Text(displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(isSelected ? .white : accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(Capsule().fill(isSelected ? accent : accent.opacity(0.08)))
                                .overlay(Capsule().strokeBorder(
                                    accent.opacity(isSelected ? 0 : 0.25), lineWidth: 0.5
                                ))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isSelected ? "\(displayName), selected" : displayName)
                    }
                }
            }
        }
    }
#endif
