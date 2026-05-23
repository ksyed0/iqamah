import IqamahCore
import SwiftUI

/// Settings section for Fasting Mode. Renders the master toggle and, when on,
/// all sub-controls. Adapts visibility/labels based on
/// `settings.calculationMethod.isShiaMethod` (AC-0371 / AC-0372 / AC-0373 / AC-0374).
///
/// Extracted to its own file so `SettingsSheetView.swift` stays under the
/// SwiftLint `file_length` limit.
public struct FastingModeSection: View {
    @ObservedObject var settings: SettingsManager

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    public var body: some View {
        Section {
            Toggle("Enable Fasting Mode", isOn: $settings.fastingModeSettings.enabled)

            if settings.fastingModeSettings.enabled {
                activationGroup
                remindersGroup
            }
        } header: {
            Label("Fasting Mode", systemImage: "moon.stars.fill")
        }
    }

    // MARK: - Activation

    @ViewBuilder private var activationGroup: some View {
        Toggle("Auto-enable during Ramadan", isOn: $settings.fastingModeSettings.autoRamadan)

        weeklyPicker

        if settings.fastingModeSettings.hasFridayAloneWarning {
            Label(
                "Friday alone is discouraged. Consider adding Thursday or Saturday.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
        if settings.fastingModeSettings.hasSaturdayAloneWarning {
            Label(
                "Saturday alone is discouraged. Consider adding Friday.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }

        Toggle("Monthly: Ayyam al-Beed (13–15)", isOn: $settings.fastingModeSettings.ayyamAlBeed)
        Toggle("Annual: 6 days of Shawwal", isOn: $settings.fastingModeSettings.sixDaysShawwal)
        Toggle("Annual: Day of Arafah (9 Dhul-Hijjah)", isOn: $settings.fastingModeSettings.dayOfArafah)
        Toggle("Annual: First 9 of Dhul-Hijjah", isOn: $settings.fastingModeSettings.firstNineDhulHijjah)

        muharramFastRow

        if settings.calculationMethod.isShiaMethod {
            Toggle("Annual: 15 Sha'ban — Laylat al-Bara'ah", isOn: $settings.fastingModeSettings.midShaban)
            Toggle("Annual: 27 Rajab — Mab'ath an-Nabi", isOn: $settings.fastingModeSettings.mabath)
        }
    }

    private var muharramFastRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: $settings.fastingModeSettings.muharramFast) {
                Text(settings.calculationMethod.isShiaMethod
                    ? "Annual: Tasu'a (9 Muharram)"
                    : "Annual: Ashura (9+10 Muharram)")
            }
            Text(settings.calculationMethod.isShiaMethod
                ? "Shia tradition: commemoration day"
                : "Sunni Sunnah fast")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Weekly picker

    /// Calendar weekday convention: 1=Sunday, 2=Monday, ..., 7=Saturday.
    /// Order respects `Calendar.current.firstWeekday` and uses locale-aware symbols.
    private var orderedWeekdays: [(day: Int, short: String)] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols // 7 entries, index 0 = Sunday
        let first = cal.firstWeekday // 1...7
        return (0 ..< 7).map { offset in
            let weekday = ((first - 1 + offset) % 7) + 1
            return (day: weekday, short: symbols[weekday - 1])
        }
    }

    private var weeklyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekly schedule").font(.subheadline)
            HStack(spacing: 6) {
                ForEach(orderedWeekdays, id: \.day) { wd in
                    weekdayChip(day: wd.day, label: wd.short)
                }
            }
        }
    }

    private func weekdayChip(day: Int, label: String) -> some View {
        let selected = settings.fastingModeSettings.weeklyDays.contains(day)
        return Button {
            toggleWeekday(day)
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(minWidth: 32, minHeight: 32)
                .background(
                    Circle().fill(selected
                        ? Color(red: 0.79, green: 0.63, blue: 0.23)
                        : Color.gray.opacity(0.2))
                )
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func toggleWeekday(_ day: Int) {
        if settings.fastingModeSettings.weeklyDays.contains(day) {
            settings.fastingModeSettings.weeklyDays.remove(day)
        } else {
            settings.fastingModeSettings.weeklyDays.insert(day)
        }
    }

    // MARK: - Reminders

    @ViewBuilder private var remindersGroup: some View {
        Toggle("Send system notifications", isOn: $settings.fastingModeSettings.notificationsEnabled)

        if settings.fastingModeSettings.notificationsEnabled {
            Stepper(value: $settings.fastingModeSettings.suhoorLeadMinutes, in: 5 ... 120, step: 5) {
                Text("Suhoor lead time: \(settings.fastingModeSettings.suhoorLeadMinutes) min")
            }
            Stepper(value: $settings.fastingModeSettings.iftarLeadMinutes, in: 5 ... 120, step: 5) {
                Text("Iftar lead time: \(settings.fastingModeSettings.iftarLeadMinutes) min")
            }
            Toggle("Notify night before fasting day", isOn: $settings.fastingModeSettings.dayBeforeEnabled)
            if settings.fastingModeSettings.dayBeforeEnabled {
                HStack {
                    Text("Day-before time")
                    Spacer()
                    Stepper(value: $settings.fastingModeSettings.dayBeforeHour, in: 0 ... 23) {
                        Text(dayBeforeTimeLabel)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var dayBeforeTimeLabel: String {
        let h = settings.fastingModeSettings.dayBeforeHour
        let m = settings.fastingModeSettings.dayBeforeMinute
        return String(format: "%02d:%02d", h, m)
    }
}
