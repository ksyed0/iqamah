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
                .background(HilalWatchWindowOpener())
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

/// Zero-size trampoline view that bridges NotificationCenter → openWindow environment action.
/// `@Environment(\.openWindow)` is only available inside a View body, not in the App struct,
/// so this hidden background view captures the action and responds to `.openHilalWatch`.
private struct HilalWatchWindowOpener: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        EmptyView()
            .onReceive(NotificationCenter.default.publisher(for: .openHilalWatch)) { _ in
                openWindow(id: "hilalWatch")
            }
    }
}
