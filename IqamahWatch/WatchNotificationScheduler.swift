import IqamahCore
import UserNotifications

// MARK: - Protocol for dependency injection (enables unit testing without live UNUserNotificationCenter)

protocol WatchNotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: WatchNotificationCenterProtocol {}

@MainActor
final class WatchNotificationScheduler {
    static let shared = WatchNotificationScheduler()
    let center: any WatchNotificationCenterProtocol

    init(center: any WatchNotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func rescheduleAll(settings: SettingsManager) async {
        let granted = await (try? center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        center.removeAllPendingNotificationRequests()

        guard let coord = settings.activeCoordinate,
              let timezone = TimeZone(identifier: settings.activeTimezoneIdentifier) else { return }

        let calc = PrayerCalculator(
            coordinate: coord,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for dayOffset in 0 ..< 7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = try? calc.calculate(for: day) else { continue }

            for prayer in times.prayers {
                guard settings.isPrayerEnabled(prayer.name),
                      prayer.name != "Sunrise",
                      prayer.time > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Time for \(prayer.name)"
                content.subtitle = settings.activeCityName
                content.sound = .default
                content.interruptionLevel = .timeSensitive

                let id = "watch.prayer.\(prayer.name).\(formatter.string(from: day))"
                let comps = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: prayer.time
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                try? await center.add(
                    UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                )
            }
        }
    }

    func cancel() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Fasting Mode reminders

    private var fastingDebounce: DispatchWorkItem?

    /// Debounced entry point — coalesces rapid settings changes into one reschedule.
    func requestFastingReschedule() {
        fastingDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.rescheduleFastingNow()
            }
        }
        fastingDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Cancels existing fastingmode.* notifications and posts a fresh 7-day window.
    ///
    /// watchOS caps pending notifications at ~64 system-wide. With at most 3
    /// Fasting Mode notifications per day (Suhoor + Iftar + day-before) the
    /// worst-case 7-day footprint is ~21 — comfortably under quota — but we
    /// iterate dayOffset=0 first so the immediate next-day window always wins
    /// if the system rejects later additions.
    func rescheduleFastingNow() async {
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
        let granted = await (try? center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

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

        let ctx = FastingScheduleContext(
            calculator: calculator, fasting: fasting, method: settings.calculationMethod,
            hijriCalendar: hijriCalendar, gregCal: gregCal, timezone: timezone, now: now
        )

        // Soonest-first: dayOffset 0..<7 prioritizes today/tomorrow under watchOS's quota.
        for dayOffset in 0 ..< 7 {
            guard let day = gregCal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            await scheduleFastingSuhoorIftar(for: day, ctx: ctx)
            if dayOffset < 6 {
                await scheduleFastingDayBefore(offsetFromNow: dayOffset + 1, ctx: ctx)
            }
        }
    }

    /// Bundles per-reschedule constants so per-day helpers stay below SwiftLint's parameter cap.
    private struct FastingScheduleContext {
        let calculator: PrayerCalculator
        let fasting: FastingModeSettings
        let method: CalculationMethod
        let hijriCalendar: Calendar
        let gregCal: Calendar
        let timezone: TimeZone
        let now: Date
    }

    private func scheduleFastingSuhoorIftar(for day: Date, ctx: FastingScheduleContext) async {
        let state = FastingModeEngine.evaluate(
            for: day, settings: ctx.fasting, calculationMethod: ctx.method,
            hijriCalendar: ctx.hijriCalendar, timezone: ctx.timezone
        )
        guard state.isActive, let times = try? ctx.calculator.calculate(for: day) else { return }
        let suhoor = FastingNotificationPlanner.suhoorFireDate(fajr: times.fajr, settings: ctx.fasting)
        let iftar = FastingNotificationPlanner.iftarFireDate(maghrib: times.maghrib, settings: ctx.fasting)
        let glyph = state.trigger == .autoRamadan ? "🌙" : "🕗"
        if suhoor > ctx.now {
            await scheduleFasting(
                at: suhoor,
                title: "\(glyph) Suhoor reminder",
                body: "Suhoor ends in \(ctx.fasting.suhoorLeadMinutes) min",
                identifier: FastingNotificationPlanner.identifier(for: day, kind: "suhoor", timezone: ctx.timezone)
            )
        }
        if iftar > ctx.now {
            await scheduleFasting(
                at: iftar,
                title: "\(glyph) Iftar approaches",
                body: "Iftar in \(ctx.fasting.iftarLeadMinutes) min",
                identifier: FastingNotificationPlanner.identifier(for: day, kind: "iftar", timezone: ctx.timezone)
            )
        }
    }

    private func scheduleFastingDayBefore(offsetFromNow: Int, ctx: FastingScheduleContext) async {
        guard let tomorrow = ctx.gregCal.date(byAdding: .day, value: offsetFromNow, to: ctx.now) else { return }
        let tState = FastingModeEngine.evaluate(
            for: tomorrow, settings: ctx.fasting, calculationMethod: ctx.method,
            hijriCalendar: ctx.hijriCalendar, timezone: ctx.timezone
        )
        guard let plan = FastingNotificationPlanner.dayBefore(
            tomorrow: tomorrow, tomorrowState: tState, settings: ctx.fasting,
            hijriCalendar: ctx.hijriCalendar, timezone: ctx.timezone
        ), plan.fireDate > ctx.now else { return }
        await scheduleFasting(at: plan.fireDate, title: plan.title, body: plan.body, identifier: plan.identifier)
    }

    private func scheduleFasting(at date: Date, title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }
}
