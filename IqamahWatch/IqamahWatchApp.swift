import CoreLocation
import IqamahCore
import SwiftUI

@main
struct IqamahWatchApp: App {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var locationSetup = WatchLocationSetup()

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
        if settings.activeCoordinate != nil {
            isReady = true
            return
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
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
