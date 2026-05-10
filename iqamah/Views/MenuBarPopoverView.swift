//
//  MenuBarPopoverView.swift
//  iqamah
//
//  Created for US-0015: Menu bar popover with countdown, prayer list, and per-prayer mutes.
//

import SwiftUI
import CoreLocation
import Combine
import IqamahCore

// MARK: - Main popover view

struct MenuBarPopoverView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var player = AdhaaanPlayer.shared
    @StateObject private var timer = PopoverTimerState()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            popoverHeader
            datebar
            columnHeaders
            prayerList
            popoverFooter
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(settings.appearance.colorScheme)
        .onAppear { timer.start(settings: settings) }
        .onDisappear { timer.stop() }
    }

    // MARK: Header

    private var popoverHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cityMethodLine)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Text(timer.countdownString)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appGold)
                    .monospacedDigit()
                    .accessibilityLabel(timer.nextPrayerName.map {
                        "Time until \($0): \(timer.countdownString)"
                    } ?? "No upcoming prayer")

                if let name = timer.nextPrayerName, let timeStr = timer.nextPrayerTimeString {
                    Text("until \(name) at \(timeStr)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 3) {
                Button(action: { AdhaaanPlayer.shared.toggleMute() }) {
                    Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(player.isMuted ? .secondary : Color.appGold)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(player.isMuted
                                    ? Color.secondary.opacity(0.08)
                                    : Color.appGold.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help(player.isMuted ? "Unmute all adhaan" : "Mute all adhaan")
                .accessibilityLabel(player.isMuted ? "Unmute all adhaan sounds" : "Mute all adhaan sounds")

                Text("All sounds")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Date bar

    private var datebar: some View {
        Text(dateBarString)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.03))
            .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: Column headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            // Icon placeholder
            Color.clear.frame(width: 28 + 8 + 16) // icon + gap + leading pad
            Text("Prayer")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Time")
                .frame(width: 72, alignment: .trailing)
            Color.clear.frame(width: 1 + 20) // divider + padding
            Text("Sound")
                .frame(width: 44, alignment: .center)
            Color.clear.frame(width: 12) // trailing pad
        }
        .font(.system(size: 9, weight: .bold))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }

    // MARK: Prayer list

    private var prayerList: some View {
        VStack(spacing: 0) {
            ForEach(timer.rows) { row in
                if row.isSunrise {
                    PopoverSunriseRow(timeString: row.timeString)
                } else {
                    PopoverPrayerRow(
                        row: row,
                        isNext: row.name == timer.nextPrayerName,
                        isGlobalMuted: player.isMuted,
                        settings: settings
                    )
                }
            }
        }
    }

    // MARK: Footer

    private var popoverFooter: some View {
        HStack {
            Spacer()
            Button("Open main window →") {
                NSApp.sendAction(#selector(AppDelegate.showWindow), to: nil, from: nil)
                NSApp.sendAction(#selector(AppDelegate.closePopover), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Divider().opacity(0.4) }
    }

    // MARK: Helpers

    private var cityMethodLine: String {
        let city = settings.locationSource == "gps" && !settings.gpsLocality.isEmpty
            ? settings.gpsLocality
            : settings.loadCity()?.name ?? "—"
        return "📍 \(city) · \(settings.calculationMethod.shortName)"
    }

    private var dateBarString: String {
        let date = Date()
        let greg = DateFormatter()
        greg.dateFormat = "EEEE, d MMM yyyy"
        let hijri = DateFormatter()
        hijri.calendar = Calendar(identifier: .islamicUmmAlQura)
        hijri.dateFormat = "d MMMM yyyy"
        return "\(greg.string(from: date)) · \(hijri.string(from: date)) AH"
    }
}

// MARK: - Prayer row

struct PopoverPrayerRow: View {
    let row: PopoverRowData
    let isNext: Bool
    let isGlobalMuted: Bool
    @ObservedObject var settings: SettingsManager

    private var isPrayerMuted: Bool { settings.isPrayerMuted(row.name) }

    var body: some View {
        HStack(spacing: 0) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(isNext ? Color.appGold.opacity(0.15) : Color.secondary.opacity(0.06))
                    .frame(width: 28, height: 28)
                Image(systemName: row.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isNext ? Color.appGold : .secondary)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)

            // Name
            Text(row.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isNext ? Color.appGold : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Time
            Text(row.timeString)
                .font(.system(size: 14, weight: isNext ? .semibold : .medium))
                .foregroundStyle(isNext ? Color.appGold : .secondary)
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 10)

            // Per-prayer mute
            Button(action: {
                settings.setPrayerMuted(!isPrayerMuted, for: row.name)
            }) {
                Image(systemName: isPrayerMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        isPrayerMuted ? Color.orange :
                            (isGlobalMuted ? Color.secondary.opacity(0.3) : Color.secondary)
                    )
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isPrayerMuted ? Color.orange.opacity(0.10) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help(isPrayerMuted ? "Unmute \(row.name) adhaan" : "Mute \(row.name) adhaan")
            .accessibilityLabel(isPrayerMuted ? "Unmute \(row.name) adhaan" : "Mute \(row.name) adhaan")
            .padding(.trailing, 12)
        }
        .frame(height: 40)
        .background(isNext ? Color.appGold.opacity(0.06) : Color.clear)
        .overlay(alignment: .bottom) { Divider().opacity(0.3) }
    }
}

// MARK: - Sunrise row

struct PopoverSunriseRow: View {
    let timeString: String

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 28 + 8 + 16)
            Text("Sunrise")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(timeString)
                .font(.system(size: 12))
                .foregroundStyle(.quaternary)
                .monospacedDigit()
                .frame(width: 72 + 1 + 20 + 28 + 12, alignment: .trailing)
                .padding(.trailing, 12)
        }
        .frame(height: 28)
        .overlay(alignment: .bottom) { Divider().opacity(0.2) }
    }
}

// MARK: - Row data model

struct PopoverRowData: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let timeString: String
    let isSunrise: Bool

    static let icons: [String: String] = [
        "Fajr": "sun.horizon.fill",
        "Sunrise": "sunrise.fill",
        "Dhuhr": "sun.max.fill",
        "Asr": "sun.min.fill",
        "Maghrib": "sunset.fill",
        "Isha": "moon.stars.fill",
    ]
}

// MARK: - Timer state (1-second countdown)

@MainActor
final class PopoverTimerState: ObservableObject {
    @Published var countdownString = "—"
    @Published var nextPrayerName: String?
    @Published var nextPrayerTimeString: String?
    @Published var rows: [PopoverRowData] = []

    private var cancellable: Cancellable?

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

        let formatter = PrayerTimes.timeFormatter(for: tz, use24Hour: settings.use24HourTime)
        let now = Date()

        // Build rows — prayers only (Sunrise inserted after Fajr)
        let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let prayerTimes: [String: Date] = [
            "Fajr": times.fajr, "Dhuhr": times.dhuhr,
            "Asr": times.asr, "Maghrib": times.maghrib, "Isha": times.isha,
        ]

        var builtRows: [PopoverRowData] = []
        for name in prayerNames {
            guard let t = prayerTimes[name] else { continue }
            builtRows.append(PopoverRowData(
                name: name,
                icon: PopoverRowData.icons[name] ?? "clock",
                timeString: formatter.string(from: t),
                isSunrise: false
            ))
            if name == "Fajr" {
                builtRows.append(PopoverRowData(
                    name: "Sunrise",
                    icon: PopoverRowData.icons["Sunrise"] ?? "sunrise.fill",
                    timeString: formatter.string(from: times.sunrise),
                    isSunrise: true
                ))
            }
        }
        rows = builtRows

        // Find next prayer using adjusted times
        let adjustedPrayers: [(String, Date)] = prayerNames.compactMap { name in
            guard let t = prayerTimes[name] else { return nil }
            let adj = settings.getAdjustment(for: name)
            return (name, Calendar.current.date(byAdding: .minute, value: adj, to: t) ?? t)
        }

        if let next = adjustedPrayers.first(where: { $0.1 > now }) {
            nextPrayerName = next.0
            nextPrayerTimeString = formatter.string(from: next.1)
            let diff = Int(next.1.timeIntervalSince(now))
            let h = diff / 3600, m = (diff % 3600) / 60, s = diff % 60
            countdownString = h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
        } else {
            nextPrayerName = nil
            nextPrayerTimeString = nil
            countdownString = "—"
        }
    }
}
