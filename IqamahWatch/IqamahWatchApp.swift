import CoreLocation
import IqamahCore
import SwiftUI

@main
struct IqamahWatchApp: App {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var locationSetup = WatchLocationSetup()

    init() {
        // Pre-seed Toronto / ISNA settings so XCUITests skip location setup (AC-0336, US-0068).
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            if let toronto = try? City(name: "Toronto", countryCode: "CA",
                                       latitude: 43.6534, longitude: -79.3834,
                                       timezone: "America/Toronto") {
                SettingsManager.shared.completeSetup(city: toronto,
                                                     calculationMethod: .isna,
                                                     asrMethod: .standard)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if locationSetup.isReady {
                    MainWatchView()
                        .environmentObject(settings)
                } else {
                    LocationSetupView(setup: locationSetup)
                }
            }
            .onAppear {
                locationSetup.start(settings: settings)
                WatchSessionManager.shared.activate(settings: settings)
            }
            .onChange(of: settings.hilalNotificationEnabled) { _, enabled in
                Task {
                    if enabled {
                        await WatchNotificationScheduler.shared.rescheduleAll(settings: settings)
                    } else {
                        WatchNotificationScheduler.shared.cancel()
                    }
                }
            }
        }
    }
}

struct MainWatchView: View {
    var body: some View {
        TabView {
            PrayerTimesTab()
            QiblaTab()
            SettingsTab()
        }
        .tabViewStyle(.page)
    }
}

@MainActor
final class WatchLocationSetup: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isReady = false
    @Published var statusMessage: String = "Detecting your location…"
    private let manager = CLLocationManager()
    private var settingsRef: SettingsManager?

    func start(settings: SettingsManager) {
        settingsRef = settings
        // Skip location detection in XCUITests — coordinates already pre-seeded.
        if ProcessInfo.processInfo.arguments.contains("--uitesting") || settings.activeCoordinate != nil {
            isReady = true
            return
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        // If permission is already granted, requestWhenInUseAuthorization() is a no-op
        // and the delegate callback may not fire — so check the current status explicitly
        // and call requestLocation() directly when already authorised.
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            statusMessage = "Enable location in Watch Settings"
            isReady = true
            return
        default: // .notDetermined — show the permission prompt
            manager.requestWhenInUseAuthorization()
        }

        // Watchdog: if GPS hasn't resolved after 20 s (simulator or denied), mark ready
        // so the user lands on prayer times with a "select location in Settings" prompt.
        Task {
            try? await Task.sleep(for: .seconds(20))
            await MainActor.run {
                guard !isReady else { return }
                statusMessage = "Couldn't detect location — open Settings to choose a city."
                isReady = true
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                statusMessage = "Enable location in Watch Settings"
                isReady = true
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            guard let settings = settingsRef else { return }
            settings.saveGPSCoordinates(loc.coordinate)
            settings.locationSource = "gps"
            settings.gpsTimezone = TimeZone.current.identifier
            isReady = true
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        Task { @MainActor in
            statusMessage = "Location unavailable — tap to retry"
            isReady = true
        }
    }
}
