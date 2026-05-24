import AppKit
import SwiftUI
import CoreLocation
import IqamahCore
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?
    var updateTimer: Timer?
    private var popover: NSPopover?

    // MARK: - Adhaan auto-play tracking

    // Keyed by "PrayerName-yyyy-MM-dd" (e.g. "Fajr-2026-05-01").
    // Prevents the same prayer from being announced more than once per day
    // even if the 60-second timer fires multiple times within the trigger window.
    private var announcedPrayers: Set<String> = []
    private var announcedDate = Date()

    // BUG-0069: held strongly so the one-shot CLLocationManager callback fires.
    // Accessed by the extension below; SwiftLint's strict_fileprivate rule allows
    // this when the access is needed across same-file extensions.
    // swiftlint:disable:next strict_fileprivate
    fileprivate var autoDetectLocationService: LocationService?

    func applicationDidFinishLaunching(_: Notification) {
        // Bootstrap UI test state before any other setup so SettingsManager
        // reads the seeded city when ContentView first renders.
        if CommandLine.arguments.contains("--uitesting") {
            bootstrapUITestSettings()
        }

        // Start as a menu-bar-only agent (no dock icon, no Cmd+Tab).
        // We do this in code rather than via LSUIElement in the plist so that
        // setActivationPolicy(.regular) works fully when the window is shown.
        NSApplication.shared.setActivationPolicy(.accessory)

        setupStatusBarItem()
        startUpdateTimer()
        // Request notification authorization so .timeSensitive alerts can break
        // through macOS Focus/DND when the app is in the background.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .settingsDidChange,
            object: nil
        )

        // Fasting Mode reminders — schedule at launch + on every settings change
        // (debounced inside the scheduler). Day-rollover reschedule is wired in
        // triggerAdhaanIfNeeded where we already detect midnight.
        FastingNotificationScheduler.shared.requestReschedule()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                self.mainWindow = window
                window.delegate = self
                window.center()
            }
        }

        // BUG-0069: launch-time auto-detect (opt-in, one-shot). Skips silently if the
        // user hasn't completed setup or has disabled the toggle.
        performAutoDetectMoveCheck()
    }

    @objc private func settingsDidChange() {
        updateStatusBarDisplay()
        resizeWindowForScale()
        MainActor.assumeIsolated {
            FastingNotificationScheduler.shared.requestReschedule()
        }
    }

    private func resizeWindowForScale() {
        // Dispatch after the current run-loop turn so SwiftUI's scaleEffect
        // re-render has updated the view hierarchy before we resize the window.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = mainWindow else { return }
            let scale = SettingsManager.shared.uiScale
            let border: CGFloat = 20 // 10pt fixed padding on each side
            let newSize = NSSize(width: 620 * scale + border, height: 680 * scale + border)
            // Don't animate during the live-preview rapid taps — just snap.
            // Only animate for larger jumps (e.g. restoring on cancel).
            let currentSize = window.frame.size
            let shouldAnimate = abs(currentSize.width - newSize.width) > 30
            let currentFrame = window.frame
            let newOriginX = currentFrame.midX - newSize.width / 2
            let newOriginY = currentFrame.midY - newSize.height / 2
            let newFrame = NSRect(origin: NSPoint(x: newOriginX, y: newOriginY), size: newSize)
            if shouldAnimate {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(newFrame, display: true)
                }
            } else {
                window.setFrame(newFrame, display: true, animate: false)
            }
        }
    }

    // MARK: - UI Test bootstrap

    /// Pre-seeds Toronto / ISNA settings so XCUITests start on the prayer times view.
    /// Called only when launched with the `--uitesting` argument (AC-0317, US-0066).
    private func bootstrapUITestSettings() {
        let toronto = try? IqamahCore.City(
            name: "Toronto",
            countryCode: "CA",
            latitude: 43.6534,
            longitude: -79.3834,
            timezone: "America/Toronto"
        )
        if let city = toronto {
            SettingsManager.shared.completeSetup(
                city: city,
                calculationMethod: .isna,
                asrMethod: .standard
            )
        }
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            // Accessibility identifier used by XCUITests (AC-0318 / AC-0319)
            button.setAccessibilityIdentifier("iqamahStatusBarButton")
        }

        updateStatusBarDisplay()
    }

    private func startUpdateTimer() {
        updateStatusBarDisplay()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateStatusBarDisplay()
            // Tell the main window's PrayerTimesTable to re-render so the NEXT badge
            // advances automatically when a prayer time passes (parity with iOS fix).
            NotificationCenter.default.post(name: .refreshPrayerTimes, object: nil)
        }
    }

    // MARK: - Status bar display + adhaan trigger

    private func updateStatusBarDisplay() {
        guard let button = statusItem?.button else { return }

        let settings = SettingsManager.shared

        guard settings.hasCompletedSetup, let city = settings.loadCity() else {
            button.attributedTitle = NSAttributedString(string: "")
            button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Iqamah")
            return
        }

        // ENH-001: prefer authoritative GPS locality name over nearest-city name
        let displayCity: String = if settings.locationSource == "gps", !settings.gpsLocality.isEmpty {
            settings.gpsLocality
        } else {
            settings.loadCity()?.name ?? "—"
        }
        _ = displayCity // available for future status bar city display

        let timezone = TimeZone(identifier: city.timezone) ?? .current
        let calculator = PrayerCalculator(
            coordinate: city.coordinate,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )

        guard let prayerTimes = try? calculator.calculate(for: Date()) else {
            button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Iqamah")
            return
        }

        let now = Date()

        // Build adjusted prayer times once — used for both display and adhaan trigger
        let adjustedPrayers: [(name: String, time: Date)] = prayerTimes.prayers.map { prayer in
            let adj = settings.getAdjustment(for: prayer.name)
            let t = Calendar.current.date(byAdding: .minute, value: adj, to: prayer.time) ?? prayer.time
            return (prayer.name, t)
        }

        // Trigger adhaan for any prayer whose time just arrived
        triggerAdhaanIfNeeded(adjustedPrayers: adjustedPrayers, now: now, settings: settings, timezone: timezone)

        // Find next upcoming prayer for status bar display
        var nextPrayer = adjustedPrayers.first { $0.time > now }

        if nextPrayer == nil {
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
                  let tomorrowTimes = try? calculator.calculate(for: tomorrow) else {
                button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Iqamah")
                return
            }
            let adj = settings.getAdjustment(for: "Fajr")
            let adjustedFajr = Calendar.current.date(byAdding: .minute, value: adj, to: tomorrowTimes.fajr) ?? tomorrowTimes.fajr
            nextPrayer = ("Fajr", adjustedFajr)
        }

        guard let next = nextPrayer else {
            button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Iqamah")
            return
        }

        let formatter = PrayerTimes.timeFormatter(for: timezone, use24Hour: settings.use24HourTime)
        let fastingState = FastingModeEngine.evaluate(
            for: now,
            settings: settings.fastingModeSettings,
            calculationMethod: settings.calculationMethod,
            hijriCalendar: Calendar(identifier: .islamicUmmAlQura),
            timezone: timezone
        )
        let labeledName = FastingLabelFormatter.relabel(
            prayerName: next.name,
            prayerTime: next.time,
            currentTime: now,
            state: fastingState
        )
        let displayText = "\(labeledName) \(formatter.string(from: next.time))"
        let minutesUntil = Int(next.time.timeIntervalSince(now) / 60)

        let textColor: NSColor = minutesUntil < 10 ? .systemRed : .labelColor
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium),
        ]

        button.image = nil
        button.attributedTitle = NSAttributedString(string: displayText, attributes: attributes)
    }

    // MARK: - Adhaan auto-play

    private func triggerAdhaanIfNeeded(
        adjustedPrayers: [(name: String, time: Date)],
        now: Date,
        settings: SettingsManager,
        timezone: TimeZone
    ) {
        // Reset the daily tracking set at midnight
        if !Calendar.current.isDate(now, inSameDayAs: announcedDate) {
            announcedPrayers.removeAll()
            announcedDate = now
            // Advance the 7-day fasting notification window on day rollover.
            MainActor.assumeIsolated {
                FastingNotificationScheduler.shared.requestReschedule()
            }
        }

        let dateKey: (String) -> String = { name in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return "\(name)-\(fmt.string(from: now))"
        }

        for prayer in adjustedPrayers where prayer.name != "Sunrise" {
            let elapsed = now.timeIntervalSince(prayer.time)

            // Trigger window: [0s, 90s) after prayer time.
            // 90s safely covers one full 60s polling cycle with a 30s buffer.
            guard elapsed >= 0, elapsed < 90 else { continue }

            let key = dateKey(prayer.name)
            guard !announcedPrayers.contains(key) else { continue }

            // Mark as handled regardless of mute state — avoids re-announcing
            // once the window is cleared after a mute toggle
            announcedPrayers.insert(key)

            guard !settings.isPrayerMuted(prayer.name) else { continue }

            let adhaan = settings.getAdhaan(for: prayer.name)
            guard adhaan.id != "silent" else { continue }

            DispatchQueue.main.async {
                AdhaaanPlayer.shared.play(adhaan)

                // Banner only for full adhaan recordings (adhaan_*).
                // Alert tones (tone_*) are short — no banner.
                if adhaan.id.hasPrefix("adhaan_") {
                    AdhaanBannerController.shared.show(
                        prayerName: prayer.name,
                        prayerTime: prayer.time,
                        adhaan: adhaan,
                        allPrayers: adjustedPrayers,
                        timezone: timezone // city's timezone, not device timezone
                    )
                }
            }

            // Post a .timeSensitive system notification so the alert surfaces even
            // when macOS Focus/DND is active (app-in-background scenario).
            // The in-app banner handles the foreground case; this covers background.
            let content = UNMutableNotificationContent()
            content.title = "Iqamah"
            content.body = "It is time for \(prayer.name)"
            content.interruptionLevel = .timeSensitive
            let req = UNNotificationRequest(
                identifier: "macos.prayer.\(prayer.name).\(dateKey(prayer.name))",
                content: content, trigger: nil
            )
            UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
        }
    }

    // MARK: - Window management

    @objc func statusBarButtonClicked(_: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            showPopover()
        }
    }

    private func makePopover() -> NSPopover {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: 440)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(rootView: MenuBarPopoverView())
        return pop
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        if popover == nil { popover = makePopover() }
        guard let pop = popover else { return }
        if pop.isShown {
            pop.close()
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        // Identity header — non-interactive
        let headerItem = NSMenuItem()
        let city = SettingsManager.shared.locationSource == "gps" && !SettingsManager.shared.gpsLocality.isEmpty
            ? SettingsManager.shared.gpsLocality
            : SettingsManager.shared.loadCity()?.name ?? "Iqamah"
        let method = SettingsManager.shared.calculationMethod.shortName
        let headerView = NSHostingView(rootView:
            VStack(alignment: .leading, spacing: 2) {
                Text("Iqamah")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text("📍 \(city) · \(method)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(width: 220, alignment: .leading))
        headerView.frame = NSRect(x: 0, y: 0, width: 220, height: 46)
        headerItem.view = headerView
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        let windowItem = NSMenuItem(title: "Open Main Window", action: #selector(showWindow), keyEquivalent: "")
        windowItem.target = self
        menu.addItem(windowItem)

        let moonItem = NSMenuItem(title: "Moon Sighting…", action: #selector(openHilalWatch), keyEquivalent: "")
        moonItem.target = self
        menu.addItem(moonItem)

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About Iqamah", action: #selector(openAboutFromMenu), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Iqamah", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    /// The Hilal Watch window title — used to exclude it when searching for the main window.
    private static let hilalWatchWindowTitle = "Hilal Watch"

    /// Returns the prayer-times main window, explicitly excluding the Hilal Watch window.
    /// Falls back to searching all windows so we never confuse the two.
    private var resolvedMainWindow: NSWindow? {
        // 1. Use the cached reference if it's still the right window.
        if let w = mainWindow, w.title != Self.hilalWatchWindowTitle { return w }
        // 2. Search for the first non-Hilal-Watch, non-panel window.
        let candidate = NSApplication.shared.windows.first {
            !($0 is NSPanel) && $0.title != Self.hilalWatchWindowTitle
        }
        if let w = candidate {
            mainWindow = w
            w.delegate = self
        }
        return candidate
    }

    @objc func showWindow() {
        // Switch to .regular so the app appears in Cmd+Tab while the window is open.
        // The Dock icon temporarily appears — this is expected macOS behaviour for
        // hybrid menu-bar/window apps (same pattern used by Bartender, Fantastical, etc.).
        NSApplication.shared.setActivationPolicy(.regular)
        if let window = resolvedMainWindow {
            // Un-minimise if needed — makeKeyAndOrderFront alone doesn't restore from Dock
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc func toggleWindow() {
        if let window = resolvedMainWindow {
            if window.isVisible {
                hideWindow(window)
            } else {
                showWindow()
            }
        } else {
            showWindow()
        }
    }

    private func hideWindow(_ window: NSWindow) {
        window.orderOut(nil)
        // Return to accessory policy: remove from Cmd+Tab and Dock
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    @objc func openHilalWatch() {
        NotificationCenter.default.post(name: .openHilalWatch, object: nil)
        // openWindow(id:) is async — activate after a brief run-loop turn so the
        // Hilal Watch window has been created and is ready to receive focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    @objc func openSupport() {
        // swiftlint:disable:next force_unwrapping
        NSWorkspace.shared.open(URL(string: "https://www.fablesoft.biz/products/iqamah/support")!)
    }

    @objc func openPrivacy() {
        // swiftlint:disable:next force_unwrapping
        NSWorkspace.shared.open(URL(string: "https://www.fablesoft.biz/products/iqamah/privacy")!)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc func closePopover() {
        popover?.close()
    }

    @objc func openSettingsFromMenu() {
        showWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }

    @objc func openAboutFromMenu() {
        showWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .openAbout, object: nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow(sender)
        return false
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func applicationDidResignActive(_: Notification) {}

    func applicationDidBecomeActive(_: Notification) {
        if updateTimer == nil {
            startUpdateTimer()
        } else {
            updateStatusBarDisplay()
        }
    }
}

// MARK: - BUG-0069 auto-detect (extracted to keep AppDelegate under type_body_length)

extension AppDelegate {
    @MainActor
    func performAutoDetectMoveCheck() {
        let settings = SettingsManager.shared
        guard settings.hasCompletedSetup, settings.autoDetectOnMove else { return }
        guard settings.loadCity() != nil else { return }

        let service = LocationService()
        autoDetectLocationService = service
        Task { @MainActor in
            do {
                let coord = try await service.requestLocationAsync()
                let outcome = AutoDetectMoveCheck.evaluate(
                    settings: settings,
                    currentCoordinate: coord
                )
                guard case let .shouldPrompt(distance, savedName) = outcome else {
                    autoDetectLocationService = nil
                    return
                }
                CLGeocoder().reverseGeocodeLocation(
                    CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                ) { placemarks, _ in
                    let locality = placemarks?.first?.locality
                        ?? placemarks?.first?.name
                        ?? ""
                    DispatchQueue.main.async {
                        let payload = MoveDetectedPayload(
                            savedCityName: savedName,
                            detectedCoordinate: coord,
                            distanceMeters: distance,
                            detectedLocality: locality
                        )
                        NotificationCenter.default.post(name: .didDetectMove, object: payload)
                        self.autoDetectLocationService = nil
                    }
                }
            } catch {
                autoDetectLocationService = nil
            }
        }
    }
}
