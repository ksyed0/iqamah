import IqamahCore
import SwiftUI

/// Shared dual-countdown banner for Fasting Mode.
/// Renders either: active state (Suhoor ends + Iftar at), or prohibition message.
/// Callers must gate on `state.isActive || state.prohibition != nil` before rendering.
///
/// Used by macOS popover (Task 11) and iOS hero card (Task 12).
/// AC-0366, AC-0367.
public struct FastingBanner: View {
    let state: FastingDayState
    let fajrTime: Date?
    let maghribTime: Date?
    let isShiaMethod: Bool

    public init(state: FastingDayState, fajrTime: Date?, maghribTime: Date?, isShiaMethod: Bool) {
        self.state = state
        self.fajrTime = fajrTime
        self.maghribTime = maghribTime
        self.isShiaMethod = isShiaMethod
    }

    public var body: some View {
        if let prohibition = state.prohibition {
            prohibitionBanner(prohibition)
        } else if state.isActive {
            activeBanner
        } else {
            EmptyView() // caller should not have rendered us
        }
    }

    private var activeBanner: some View {
        let isRamadan = state.trigger == .autoRamadan
        let gradient: LinearGradient = isRamadan
            ? LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.10, blue: 0.23),
                    Color(red: 0.10, green: 0.16, blue: 0.23),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.23, blue: 0.23),
                    Color(red: 0.10, green: 0.16, blue: 0.23),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        let glyph = isRamadan ? "🌙" : "🕗"
        let gold = Color(red: 0.79, green: 0.63, blue: 0.23)

        return HStack(alignment: .center, spacing: 12) {
            Text(glyph).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                if let fajr = fajrTime {
                    HStack {
                        Text("Suhoor ends")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(gold)
                        Spacer()
                        Text(formatted(fajr))
                            .font(.caption).fontWeight(.medium).monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                if let maghrib = maghribTime {
                    HStack {
                        Text("Iftar at")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(gold)
                        Spacer()
                        Text(formatted(maghrib))
                            .font(.caption).fontWeight(.medium).monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(gold.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func prohibitionBanner(_ prohibition: ProhibitedDay) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("⚠️").font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(prohibition.displayName)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("Fasting is forbidden today")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.16), Color(white: 0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
    }

    private func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
