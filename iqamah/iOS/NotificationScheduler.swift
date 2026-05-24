#if os(iOS)
    import Foundation
    import IqamahCore
    import UserNotifications

    /// Schedules local prayer-time notifications for the next 7 days.
    ///
    /// Called whenever settings change (city, method, enabledPrayers) and on
    /// each app-active transition. At most 35 pending notifications (7 days × 5
    /// prayers) — well within iOS's 64-notification limit.
    @MainActor
    final class NotificationScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
        static let shared = NotificationScheduler()

        private let center = UNUserNotificationCenter.current()

        override private init() {
            super.init()
            center.delegate = self
        }

        // MARK: - Authorisation

        /// Requests notification authorisation if not yet determined.
        /// Returns true if authorised (or already authorised).
        func requestAuthorizationIfNeeded() async -> Bool {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                return await (try? center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            case .authorized, .provisional, .ephemeral:
                return true
            case .denied:
                return false
            @unknown default:
                return false
            }
        }

        // MARK: - Scheduling

        /// Cancels all pending prayer notifications and reschedules 7 days ahead.
        func rescheduleAll() async {
            guard await requestAuthorizationIfNeeded() else { return }
            center.removeAllPendingNotificationRequests()

            let settings = SettingsManager.shared
            guard let coord = settings.activeCoordinate else { return }
            let timezoneId = settings.activeTimezoneIdentifier
            guard let timezone = TimeZone(identifier: timezoneId) else { return }

            let calc = PrayerCalculator(
                coordinate: coord,
                timezone: timezone,
                method: settings.calculationMethod,
                asrMethod: settings.asrMethod
            )

            let calendar = Calendar(identifier: .gregorian)
            let now = Date()

            for dayOffset in 0 ..< 7 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                guard let times = try? calc.calculate(for: day) else { continue }

                for prayer in times.prayers {
                    guard settings.isPrayerEnabled(prayer.name) else { continue }
                    guard prayer.time > now else { continue } // skip times already past today
                    let request = makeRequest(name: prayer.name, time: prayer.time, day: day, settings: settings)
                    try? await center.add(request)
                }
            }
        }

        // MARK: - Request construction

        private func makeRequest(
            name: String,
            time: Date,
            day: Date,
            settings: SettingsManager
        ) -> UNNotificationRequest {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let id = "prayer.\(name).\(formatter.string(from: day))"

            let content = UNMutableNotificationContent()
            content.title = "Iqamah"
            content.body = "It is time for \(name)"
            content.sound = resolveSound(for: name, settings: settings)
            content.userInfo = ["prayerName": name]
            // Break through Focus/DND — prayer times are time-bound obligations.
            // .timeSensitive doesn't need a special Apple entitlement (unlike .critical).
            content.interruptionLevel = .timeSensitive

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: time
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }

        private func resolveSound(for prayer: String, settings: SettingsManager) -> UNNotificationSound {
            // Use default system sound if prayer is muted
            guard !settings.isPrayerMuted(prayer) else { return .default }

            // Resolve via the public Adhaan API — Bundle.module is internal to IqamahCore
            let adhaan = settings.getAdhaan(for: prayer)
            guard let notifFilename = adhaan.notificationSoundFilename else { return .default }

            return UNNotificationSound(named: UNNotificationSoundName(notifFilename))
        }

        // MARK: - Fasting Mode reminders

        private var fastingDebounce: DispatchWorkItem?

        /// Debounced entry point — coalesces rapid Fasting-settings changes into one reschedule.
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
            guard await requestAuthorizationIfNeeded() else { return }

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
            content.userInfo = ["destination": "fasting-mode"]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }

        // MARK: - UNUserNotificationCenterDelegate

        /// Displays the notification as a banner even while the app is in the foreground.
        nonisolated func userNotificationCenter(
            _: UNUserNotificationCenter,
            willPresent _: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .sound])
        }

        /// Handles a tap on a prayer notification — posts a notification to open the Times tab.
        nonisolated func userNotificationCenter(
            _: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            if response.notification.request.content.userInfo["prayerName"] != nil {
                NotificationCenter.default.post(name: .openPrayerTimesTab, object: nil)
            }
            completionHandler()
        }
    }

    public extension Notification.Name {
        /// Posted when a prayer notification is tapped — tells the iOS root view to switch to Times tab.
        static let openPrayerTimesTab = Notification.Name("openPrayerTimesTab")
    }
#endif
