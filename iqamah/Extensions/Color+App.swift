import SwiftUI

extension Color {
    /// Primary gold brand accent — use on dark surfaces (dark mode, glass dark rows).
    static let appGold = Color(red: 0.88, green: 0.69, blue: 0.06)

    /// Lighter gold variant used in the wordmark gradient top stop.
    static let appGoldDim = Color(red: 0.95, green: 0.76, blue: 0.06)

    /// Darker amber for gold text on light surfaces (light mode glass).
    /// #8a5e00 — meets 4.5:1 contrast on white/cream backgrounds.
    static let appGoldDark = Color(red: 0.54, green: 0.37, blue: 0.0)
}
