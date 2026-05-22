import SwiftUI

struct WatchLocationSetupView: View {
    @ObservedObject var setup: WatchLocationSetup

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text(setup.statusMessage)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
