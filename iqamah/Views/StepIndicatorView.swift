import SwiftUI

/// Compact onboarding step indicator — "Step 1 of 2" with dot pips.
struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { step in
                    Capsule()
                        .fill(step == current ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: step == current ? 20 : 8, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: current)
                }
            }
            Text("Step \(current) of \(total)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}
