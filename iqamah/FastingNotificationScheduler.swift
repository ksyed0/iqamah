import Foundation
import IqamahCore
import UserNotifications

/// macOS scheduler for Fasting Mode reminders. Wraps `UNUserNotificationCenter`
/// with a 500 ms debounce so rapid settings changes coalesce into one reschedule.
///
/// Maintains a 7-day rolling window of Suhoor + Iftar + day-before notifications,
/// driven by `FastingNotificationPlanner` for fire-date arithmetic. Cancels and
/// re-registers all `fastingmode.*` pending notifications atomically on each
/// reschedule. Permission is requested lazily — only when a reschedule actually
/// has work to do — matching the existing prayer-notification pattern.
@MainActor
final class FastingNotificationScheduler {
    static let shared = FastingNotificationScheduler()
    private init() {}

    private var debounceWorkItem: DispatchWorkItem?

    /// Debounced entry point — call from any settings observer. Coalesces rapid
    /// toggles into a single `rescheduleNow()` after 500 ms of quiet.
    func requestReschedule() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.rescheduleNow()
            }
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Immediate reschedule — clears existing `fastingmode.*` notifications and
    /// posts a fresh 7-day window. Safe to call directly (bypasses debounce) for
    /// app-launch and day-rollover triggers.
    func rescheduleNow() async {
        let center = UNUserNotificationCenter.current()

        // Atomic cancel: drop every fastingmode.* request before re-adding.
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("fastingmode.") }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        let settings = SettingsManager.shared
        let fasting = settings.fastingModeSettings
        guard fasting.enabled, fasting.notificationsEnabled else { return }
        guard let coord = settings.activeCoordinate else { return }
        let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier) ?? .current

        // Lazy authorization — only ask when we actually need it.
        guard await ensureAuthorized() else { return }

        let calculator = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        var gregCal = Calendar(identifier: .gregorian)
        gregCal.timeZone = timezone
        let now = Date()

        for dayOffset in 0 ..< 7 {
            guard let day = gregCal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            await scheduleSuhoorIftar(
                for: day, calculator: calculator, settings: fasting, method: settings.calculationMethod,
                hijriCalendar: hijriCalendar, timezone: timezone, now: now
            )
            if dayOffset < 6 {
                await scheduleDayBefore(
                    offsetFromNow: dayOffset + 1, gregCal: gregCal, now: now,
                    settings: fasting, method: settings.calculationMethod,
                    hijriCalendar: hijriCalendar, timezone: timezone
                )
            }
        }
    }

    private func scheduleSuhoorIftar(
        for day: Date,
        calculator: PrayerCalculator,
        settings: FastingModeSettings,
        method: CalculationMethod,
        hijriCalendar: Calendar,
        timezone: TimeZone,
        now: Date
    ) async {
        let state = FastingModeEngine.evaluate(
            for: day, settings: settings, calculationMethod: method,
            hijriCalendar: hijriCalendar, timezone: timezone
        )
        guard state.isActive, let times = try? calculator.calculate(for: day) else { return }
        let suhoor = FastingNotificationPlanner.suhoorFireDate(fajr: times.fajr, settings: settings)
        let iftar = FastingNotificationPlanner.iftarFireDate(maghrib: times.maghrib, settings: settings)
        let glyph = state.trigger == .autoRamadan ? "🌙" : "🕗"
        if suhoor > now {
            await schedule(
                at: suhoor,
                title: "\(glyph) Suhoor reminder",
                body: "Suhoor ends in \(settings.suhoorLeadMinutes) min — Fajr at \(format(times.fajr, tz: timezone))",
                identifier: FastingNotificationPlanner.identifier(for: day, kind: "suhoor", timezone: timezone)
            )
        }
        if iftar > now {
            await schedule(
                at: iftar,
                title: "\(glyph) Iftar approaches",
                body: "Iftar in \(settings.iftarLeadMinutes) min — Maghrib at \(format(times.maghrib, tz: timezone))",
                identifier: FastingNotificationPlanner.identifier(for: day, kind: "iftar", timezone: timezone)
            )
        }
    }

    private func scheduleDayBefore(
        offsetFromNow: Int,
        gregCal: Calendar,
        now: Date,
        settings: FastingModeSettings,
        method: CalculationMethod,
        hijriCalendar: Calendar,
        timezone: TimeZone
    ) async {
        guard let tomorrow = gregCal.date(byAdding: .day, value: offsetFromNow, to: now) else { return }
        let tState = FastingModeEngine.evaluate(
            for: tomorrow, settings: settings, calculationMethod: method,
            hijriCalendar: hijriCalendar, timezone: timezone
        )
        guard let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow, tomorrowState: tState, settings: settings,
            hijriCalendar: hijriCalendar, timezone: timezone
        ), plan.fireDate > now else { return }
        await schedule(at: plan.fireDate, title: plan.title, body: plan.body, identifier: plan.identifier)
    }

    private func schedule(at date: Date, title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["destination": "fasting-mode"]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Requests authorization once if undetermined; otherwise returns the cached state.
    private func ensureAuthorized() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return await (try? center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func format(_ date: Date, tz: TimeZone) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.timeZone = tz
        return fmt.string(from: date)
    }
}
