import SwiftUI
import IqamahCore

@main
struct iqamahApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = SettingsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 640, height: 700) // 620×680 content + 10pt border each side

        Window("Hilal Watch", id: "hilalWatch") {
            HilalWatchView()
                .environmentObject(SettingsManager.shared)
                .frame(minWidth: 600, idealWidth: 720, minHeight: 500, idealHeight: 640)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 720, height: 640)
    }
}
