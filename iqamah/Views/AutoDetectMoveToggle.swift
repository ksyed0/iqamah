import IqamahCore
import SwiftUI

// MARK: - BUG-0069 auto-detect toggle

//
// Extracted from SettingsSheetView so the parent file stays under the
// `file_length` SwiftLint rule. Shared between macOS and iOS.

struct AutoDetectMoveToggle: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Toggle(isOn: $settings.autoDetectOnMove) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-detect if I move > 25 km")
                Text("On launch, check your current location and offer to switch cities if you've moved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .help(
            "On launch, check your current location and prompt to switch cities if you've moved more than 25 kilometers from your saved city."
        )
    }
}
