import IqamahCore
import SwiftUI
import WidgetKit

@main
struct IqamahiOSApp: App {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(settings)
                // Reschedule when settings that affect prayer times change
                .onChange(of: settings.calculationMethod) { _, _ in reschedule(); reloadWidget() }
                .onChange(of: settings.asrMethod) { _, _ in reschedule(); reloadWidget() }
                .onChange(of: settings.enabledPrayers) { _, _ in reschedule() }
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
        }
    }

    private func reschedule() {
        Task { await NotificationScheduler.shared.rescheduleAll() }
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
