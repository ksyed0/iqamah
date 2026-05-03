import AppKit
import SwiftUI
import CoreLocation

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?
    var updateTimer: Timer?

    // MARK: - Adhaan auto-play tracking

    // Keyed by "PrayerName-yyyy-MM-dd" (e.g. "Fajr-2026-05-01").
    // Prevents the same prayer from being announced more than once per day
    // even if the 60-second timer fires multiple times within the trigger window.
    private var announcedPrayers: Set<String> = []
    private var announcedDate = Date()

    func applicationDidFinishLaunching(_: Notification) {
        setupStatusBarItem()
        startUpdateTimer()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .settingsDidChange,
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                self.mainWindow = window
                window.delegate = self
                window.center()
            }
        }
    }

    @objc private func settingsDidChange() {
        updateStatusBarDisplay()
        resizeWindowForScale()
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

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateStatusBarDisplay()
    }

    private func startUpdateTimer() {
        updateStatusBarDisplay()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateStatusBarDisplay()
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
        let displayText = "\(next.name) \(formatter.string(from: next.time))"
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
        }
    }

    // MARK: - Window management

    @objc func statusBarButtonClicked(_: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleWindow()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        // target must be set explicitly — NSStatusItem menus do not walk the
        // normal responder chain, so without a target the action fires into void.
        let showItem = NSMenuItem(title: "Show Prayer Times", action: #selector(showWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Iqamah", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func showWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        } else if let window = NSApplication.shared.windows.first {
            mainWindow = window
            window.delegate = self
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    @objc func toggleWindow() {
        if let window = mainWindow {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        } else {
            showWindow()
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
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
