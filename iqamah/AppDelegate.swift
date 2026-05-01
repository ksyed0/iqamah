import AppKit
import SwiftUI
import CoreLocation

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?
    var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        startUpdateTimer()

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .settingsDidChange,
            object: nil
        )

        // Find and configure the main window
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
        // Update immediately
        updateStatusBarDisplay()

        // Then update every minute
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateStatusBarDisplay()
        }
    }

    private func updateStatusBarDisplay() {
        guard let button = statusItem?.button else { return }

        let settings = SettingsManager.shared

        // Check if setup is complete and we have a saved city
        guard settings.hasCompletedSetup, let city = settings.loadCity() else {
            // Show default icon if not configured
            button.attributedTitle = NSAttributedString(string: "")
            button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Iqamah")
            return
        }

        // Calculate prayer times
        let timezone = TimeZone(identifier: city.timezone) ?? .current
        let calculator = PrayerCalculator(
            coordinate: city.coordinate,
            timezone: timezone,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )

        guard let prayerTimes = try? calculator.calculate(for: Date()) else {
            // If calculation fails, show default icon
            button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Iqamah")
            return
        }
        let now = Date()

        // Find next prayer (with adjustments)
        var nextPrayer: (name: String, time: Date)?
        for prayer in prayerTimes.prayers {
            // Apply adjustment to prayer time
            let adjustmentMinutes = settings.getAdjustment(for: prayer.name)
            let adjustedTime = Calendar.current.date(byAdding: .minute, value: adjustmentMinutes, to: prayer.time) ?? prayer.time
            
            if adjustedTime > now {
                nextPrayer = (prayer.name, adjustedTime)
                break
            }
        }

        // If no prayer found today, show Fajr (next day's first prayer)
        if nextPrayer == nil {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
            guard let tomorrowPrayers = try? calculator.calculate(for: tomorrow) else {
                button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Iqamah")
                return
            }
            let adjustmentMinutes = settings.getAdjustment(for: "Fajr")
            let adjustedFajr = Calendar.current.date(byAdding: .minute, value: adjustmentMinutes, to: tomorrowPrayers.fajr) ?? tomorrowPrayers.fajr
            nextPrayer = ("Fajr", adjustedFajr)
        }

        guard let next = nextPrayer else {
            button.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Iqamah")
            return
        }

        let formatter = PrayerTimes.timeFormatter(
            for: timezone,
            use24Hour: settings.use24HourTime
        )

        let timeString = formatter.string(from: next.time)
        let displayText = "\(next.name) \(timeString)"

        // Calculate minutes until next prayer
        let minutesUntil = Int(next.time.timeIntervalSince(now) / 60)

        // Set color based on time remaining
        let textColor: NSColor
        if minutesUntil < 10 {
            textColor = .systemRed
        } else {
            textColor = .labelColor
        }

        // Create attributed string with color
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        ]

        button.image = nil
        button.attributedTitle = NSAttributedString(string: displayText, attributes: attributes)
    }

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleWindow()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show Prayer Times", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Iqamah", action: #selector(quitApp), keyEquivalent: "q"))

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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Optionally pause timer when app goes to background
        // Uncomment to save resources when app is not active
        // updateTimer?.invalidate()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Restart timer if it was paused
        if updateTimer == nil {
            startUpdateTimer()
        } else {
            // Force update display immediately
            updateStatusBarDisplay()
        }
    }
}
