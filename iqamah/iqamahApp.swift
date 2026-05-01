import SwiftUI

@main
struct iqamahApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 640, height: 700)  // 620×680 content + 10pt border each side
    }
}
