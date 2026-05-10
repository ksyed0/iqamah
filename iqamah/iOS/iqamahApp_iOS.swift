import SwiftUI
import IqamahCore

@main
struct IqamahiOSApp: App {
    @StateObject private var settings = SettingsManager.shared

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(settings)
        }
    }
}
