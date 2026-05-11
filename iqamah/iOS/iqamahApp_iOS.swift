import IqamahCore
import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct IqamahiOSApp: App {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(settings)
                .onAppear {
                    activateWCSession()
                }
                // Reschedule when settings that affect prayer times change
                .onChange(of: settings.calculationMethod) { _, _ in reschedule(); reloadWidget(); pushSettingsToWatch() }
                .onChange(of: settings.asrMethod) { _, _ in reschedule(); reloadWidget(); pushSettingsToWatch() }
                .onChange(of: settings.enabledPrayers) { _, _ in reschedule() }
                .onChange(of: settings.use24HourTime) { _, _ in pushSettingsToWatch() }
                // Reschedule on each app-active to advance the 7-day window
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { reschedule() }
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
                .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
                    pushSettingsToWatch()
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
