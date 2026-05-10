import IqamahCore
import SwiftUI

@main
struct IqamahiOSApp: App {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(settings)
                // Reschedule when settings that affect prayer times change
                .onChange(of: settings.calculationMethod) { _, _ in reschedule() }
                .onChange(of: settings.asrMethod) { _, _ in reschedule() }
                .onChange(of: settings.enabledPrayers) { _, _ in reschedule() }
                // Reschedule on each app-active to advance the 7-day window
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { reschedule() }
                }
        }
    }

    private func reschedule() {
        Task { await NotificationScheduler.shared.rescheduleAll() }
    }
}
