import SwiftUI
import IqamahCore

/// Colour palette for the four Odeh visibility categories.
struct HilalPalette {
    static func fill(for category: VisibilityCategory, colorScheme _: ColorScheme) -> Color {
        switch category {
        case .A: Color(red: 0.13, green: 0.55, blue: 0.13) // forest green
        case .B: Color(red: 0.00, green: 0.50, blue: 0.50) // teal
        case .C: Color(red: 0.50, green: 0.50, blue: 0.50) // grey
        case .D: Color(red: 0.70, green: 0.10, blue: 0.10) // dark red
        }
    }

    static func alpha(for _: VisibilityCategory, colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.55 : 0.45
    }
}
