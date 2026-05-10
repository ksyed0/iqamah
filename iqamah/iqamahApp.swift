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
    }
}
