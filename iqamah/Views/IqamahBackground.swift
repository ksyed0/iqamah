import SwiftUI

/// Full-bleed ambient gradient that sits behind all app content.
/// Provides the rich color field that glass surfaces blur against.
struct IqamahBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ? darkGradient : lightGradient)
            .ignoresSafeArea()
    }

    private var darkGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.098, green: 0.031, blue: 0.012), location: 0.0),
                .init(color: Color(red: 0.047, green: 0.047, blue: 0.102), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lightGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 1.0, green: 0.973, blue: 0.925), location: 0.0),
                .init(color: Color(red: 0.910, green: 0.941, blue: 1.0), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
