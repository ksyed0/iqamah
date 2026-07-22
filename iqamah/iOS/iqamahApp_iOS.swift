import CoreLocation
import IqamahCore
import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct IqamahiOSApp: App {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.scenePhase) private var scenePhase
    // BUG-0069: held strongly so the one-shot CLLocationManager callback fires.
    @State private var autoDetectLocationService: LocationService?

    init() {
        // Pre-seed Toronto / ISNA settings so XCUITests skip setup flow (AC-0326, US-0067).
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            bootstrapUITestSettings()
        }
    }

    /// Mirrors the macOS AppDelegate bootstrap — must run before body is first rendered.
    private func bootstrapUITestSettings() {
        let toronto = try? City(
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

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onAppear {
                    activateWCSession()
                    NotificationScheduler.shared.requestFastingReschedule()
                    performAutoDetectMoveCheck()
                }
                .onChange(of: settings.fastingModeSettings) { _, _ in
                    NotificationScheduler.shared.requestFastingReschedule()
                }
                // Reschedule when settings that affect prayer times change
                .onChange(of: settings.calculationMethod) { _, _ in reschedule(); reloadWidget(); pushSettingsToWatch() }
                .onChange(of: settings.asrMethod) { _, _ in reschedule(); reloadWidget(); pushSettingsToWatch() }
                .onChange(of: settings.enabledPrayers) { _, _ in reschedule() }
                .onChange(of: settings.use24HourTime) { _, _ in pushSettingsToWatch() }
                // Reschedule on each app-active to advance the 7-day window
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        reschedule()
                        NotificationScheduler.shared.requestFastingReschedule()
                        reloadWidget()
                        // Tell PrayerTimesView to recalculate so "NEXT" label is current
                        NotificationCenter.default.post(name: .refreshPrayerTimes, object: nil)
                        // Pre-compute Hilal grid in background so sheet opens instantly
                        HilalWatchPreloader.shared.prefetch(settings: settings)
                        if settings.liveActivityEnabled {
                            Task { await PrayerActivityManager.shared.startOrUpdateActivity(settings: settings) }
                        }
                    }
                }
                .onChange(of: settings.hilalNotificationEnabled) { _, enabled in
                    Task {
                        if enabled {
                            guard let coord = settings.activeCoordinate else { return }
                            await HilalNotificationScheduler.shared.scheduleNextWatchEvening(
                                latitude: coord.latitude,
                                longitude: coord.longitude
                            )
                        } else {
                            HilalNotificationScheduler.shared.cancel()
                        }
                    }
                }
                // Live Activity: refresh on every app-active and on settings changes
                .onChange(of: settings.liveActivityEnabled) { _, enabled in
                    Task {
                        if enabled {
                            await PrayerActivityManager.shared.startOrUpdateActivity(settings: settings)
                        } else {
                            await PrayerActivityManager.shared.endActivity()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
                    pushSettingsToWatch()
                    guard settings.liveActivityEnabled else { return }
                    Task {
                        await PrayerActivityManager.shared.startOrUpdateActivity(settings: settings)
                    }
                }
                #if os(visionOS)
                .ornament(attachmentAnchor: .scene(.bottom)) {
                    NextPrayerOrnament()
                        .environmentObject(settings)
                }
                #endif
        }
        #if os(visionOS)
        WindowGroup(id: VisionSceneIDs.qiblaVolume) {
            QiblaVolumeView()
                .environmentObject(settings)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.4, height: 0.5, depth: 0.4, in: .meters)

        ImmersiveSpace(id: VisionSceneIDs.adhanImmersive) {
            AdhanImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        #endif
    }

    /// BUG-0069: launch-time auto-detect (opt-in). Skips silently if disabled or onboarding incomplete.
    @MainActor
    private func performAutoDetectMoveCheck() {
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
                    let locality = placemarks?.first?.locality ?? placemarks?.first?.name ?? ""
                    DispatchQueue.main.async {
                        let payload = MoveDetectedPayload(
                            savedCityName: savedName,
                            detectedCoordinate: coord,
                            distanceMeters: distance,
                            detectedLocality: locality
                        )
                        NotificationCenter.default.post(name: .didDetectMove, object: payload)
                        autoDetectLocationService = nil
                    }
                }
            } catch {
                autoDetectLocationService = nil
            }
        }
    }

    private func reschedule() {
        Task { await NotificationScheduler.shared.rescheduleAll() }
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func activateWCSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.activate()
    }

    private func pushSettingsToWatch() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        var info: [String: Any] = [
            "calculationMethod": settings.calculationMethod.rawValue,
            "asrMethod": settings.asrMethod.rawValue,
            "use24HourTime": settings.use24HourTime,
        ]
        if let city = settings.loadCity() {
            info["selectedCityName"] = city.name
            info["selectedCityCountryCode"] = city.countryCode
            info["selectedCityLatitude"] = city.latitude
            info["selectedCityLongitude"] = city.longitude
            info["selectedCityTimezone"] = city.timezone
        }
        WCSession.default.transferUserInfo(info)
    }
}
