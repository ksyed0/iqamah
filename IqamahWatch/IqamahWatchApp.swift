import CoreLocation
import IqamahCore
import SwiftUI

@main
struct IqamahWatchApp: App {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var locationSetup = WatchLocationSetup()
    @StateObject private var moveDetector = WatchMoveDetector()

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
                    WatchLocationSetupView(setup: locationSetup)
                }
            }
            .onAppear {
                locationSetup.start(settings: settings)
                WatchSessionManager.shared.activate(settings: settings)
                WatchNotificationScheduler.shared.requestFastingReschedule()
                moveDetector.startIfNeeded(settings: settings)
            }
            .alert(
                "Have you moved?",
                isPresented: Binding(
                    get: { moveDetector.pendingPayload != nil },
                    set: { if !$0 { moveDetector.pendingPayload = nil } }
                ),
                presenting: moveDetector.pendingPayload
            ) { payload in
                Button("Switch") {
                    moveDetector.applySwitch(payload: payload, settings: settings)
                }
                Button("Not now", role: .cancel) {
                    moveDetector.pendingPayload = nil
                }
            } message: { payload in
                let whereText = payload.detectedLocality.isEmpty
                    ? "your current location"
                    : payload.detectedLocality
                Text("You appear to be in \(whereText), ~\(payload.distanceKmString) from \(payload.savedCityName). Switch?")
            }
            .onChange(of: settings.fastingModeSettings) { _, _ in
                WatchNotificationScheduler.shared.requestFastingReschedule()
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
            refineWithCLGeocoder(coordinate: loc.coordinate, settings: settings)
        }
    }

    @MainActor
    private func refineWithCLGeocoder(coordinate: CLLocationCoordinate2D, settings: SettingsManager) {
        // 5 km / non-empty locality cache short-circuit — mirrors macOS LocationSetupView:230-235.
        if let cached = settings.cachedGPSCoordinate() {
            let cachedLoc = CLLocation(latitude: cached.latitude, longitude: cached.longitude)
            let newLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if cachedLoc.distance(from: newLoc) < 5000, !settings.gpsLocality.isEmpty { return }
        }

        CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ) { placemarks, error in
            guard error == nil, let placemark = placemarks?.first else {
                print("[ENH-001] Watch CLGeocoder failed: \(error?.localizedDescription ?? "unknown")")
                return
            }
            let locality = placemark.locality ?? placemark.name ?? ""
            let timezone = placemark.timeZone?.identifier ?? TimeZone.current.identifier
            // Reach SettingsManager via `.shared` inside the @MainActor body rather
            // than capturing the local `settings` parameter — the CLGeocoder
            // completion handler runs on an arbitrary queue and the implicit
            // @Sendable Task closure would otherwise capture a non-Sendable
            // SettingsManager reference (Swift 6 concurrency warning).
            Task { @MainActor in
                SettingsManager.shared.applyGeocodingRefinement(
                    locality: locality,
                    timezoneIdentifier: timezone
                )
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        Task { @MainActor in
            statusMessage = "Location unavailable — tap to retry"
            isReady = true
        }
    }
}

// MARK: - BUG-0069 watch launch-time move detector

@MainActor
final class WatchMoveDetector: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var pendingPayload: MoveDetectedPayload?

    private let manager = CLLocationManager()
    private var didStart = false
    private weak var settingsRef: SettingsManager?

    func startIfNeeded(settings: SettingsManager) {
        guard !didStart else { return }
        didStart = true
        settingsRef = settings
        guard settings.hasCompletedSetup, settings.autoDetectOnMove else { return }
        guard settings.loadCity() != nil else { return }

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            // Don't badger the user — the main onboarding flow handles permission.
            return
        }
    }

    func applySwitch(payload: MoveDetectedPayload, settings: SettingsManager) {
        let locality = payload.detectedLocality.isEmpty
            ? payload.savedCityName
            : payload.detectedLocality
        if let newCity = try? City(
            name: locality,
            countryCode: settings.loadCity()?.countryCode ?? "US",
            latitude: payload.detectedCoordinate.latitude,
            longitude: payload.detectedCoordinate.longitude,
            timezone: TimeZone.current.identifier
        ) {
            settings.saveCity(newCity)
            settings.locationSource = "gps"
            settings.saveGPSCoordinates(payload.detectedCoordinate)
            settings.gpsLocality = payload.detectedLocality
            settings.gpsDetectedCity = newCity
        }
        pendingPayload = nil
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            guard let settings = settingsRef else { return }
            let outcome = AutoDetectMoveCheck.evaluate(
                settings: settings,
                currentCoordinate: loc.coordinate
            )
            guard case let .shouldPrompt(distance, savedName) = outcome else { return }
            CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
                let locality = placemarks?.first?.locality ?? placemarks?.first?.name ?? ""
                Task { @MainActor in
                    self.pendingPayload = MoveDetectedPayload(
                        savedCityName: savedName,
                        detectedCoordinate: loc.coordinate,
                        distanceMeters: distance,
                        detectedLocality: locality
                    )
                }
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        // Silent — this is opportunistic.
    }
}
