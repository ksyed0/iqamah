#if canImport(ActivityKit)
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - App gold colour (can't import macOS app targets from extension)

private let activityGold = Color(red: 1.0, green: 0.839, blue: 0.039)

// MARK: - Fasting Mode relabel helper (AC-0370)

//
// IqamahCore is intentionally not linked into the Live Activity extension to
// keep the extension binary small. The relabel logic is tiny — mirror it here
// rather than pull in the framework. Stays in sync with
// FastingLabelFormatter.relabel(...) in IqamahCore.
private let liveActivityRelabelWindow: TimeInterval = 2 * 60 * 60

private func displayedNextPrayerName(
    _ context: ActivityViewContext<PrayerActivityAttributes>
) -> String {
    guard context.state.fastingActive == true,
          let triggerRaw = context.state.fastingTriggerRaw,
          !triggerRaw.isEmpty else {
        return context.state.nextPrayerName
    }
    let newLabel: String
    switch context.state.nextPrayerName {
    case "Fajr": newLabel = "Suhoor"
    case "Maghrib": newLabel = "Iftar"
    default: return context.state.nextPrayerName
    }
    let secondsUntil = context.state.nextPrayerTime.timeIntervalSinceNow
    guard (0 ... liveActivityRelabelWindow).contains(secondsUntil) else {
        return context.state.nextPrayerName
    }
    let glyph = triggerRaw == "autoRamadan" ? "🌙" : "🕗"
    return "\(glyph) \(newLabel)"
}

// MARK: - Inline crescent (MoonPhaseView lives in macOS target; can't import it here)

private struct CrescentView: View {
    let phase: Double
    let size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let r = min(sz.width, sz.height) / 2 - 1
            let cx = sz.width / 2, cy = sz.height / 2
            // Dark disc
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                     with: .color(Color(red: 0.04, green: 0.04, blue: 0.13)))
            guard phase > 0.02 else { return }
            if phase > 0.48, phase < 0.52 {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                         with: .color(activityGold.opacity(0.92)))
                return
            }
            let waxing = phase < 0.5
            let innerRx = abs(r * (waxing ? 1 - phase * 2 : phase * 2 - 1))
            var path = Path()
            path.move(to: CGPoint(x: cx, y: cy - r))
            path.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: !waxing)
            path.addArc(center: CGPoint(x: cx, y: cy), radius: innerRx,
                        startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: waxing)
            path.closeSubpath()
            ctx.fill(path, with: .color(activityGold.opacity(0.90)))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Widget entry point

/// `@main` designates this as the extension's binary entry point.
/// Without it the OS cannot locate the widget on iOS 16.2+ and will
/// immediately terminate the extension (and the host app) at load time.
@main
@available(iOS 16.2, *)
struct PrayerLiveActivityView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(activityGold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle().fill(activityGold).frame(width: 7, height: 7)
                    Text(displayedNextPrayerName(context))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(activityGold)
                }
            } compactTrailing: {
                Text(context.state.nextPrayerTime, style: .timer)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(maxWidth: 44)
            } minimal: {
                Text(String(context.state.nextPrayerName.prefix(1)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(activityGold)
            }
        }
    }
}

// MARK: - Expanded sub-views

@available(iOS 16.2, *)
private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                CrescentView(phase: context.state.moonPhase, size: 18)
                Text(context.state.hijriDateString)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(context.attributes.cityName)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, 4)
    }
}

@available(iOS 16.2, *)
private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(displayedNextPrayerName(context))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(activityGold)
            Text(context.state.nextPrayerTime, style: .timer)
                .font(.system(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(maxWidth: 90, alignment: .trailing)
        }
        .padding(.trailing, 4)
    }
}

@available(iOS 16.2, *)
private struct ExpandedBottomView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    var body: some View {
        HStack {
            Text(
                "at \(context.state.nextPrayerTime.formatted(.dateTime.hour().minute())) · \(context.attributes.cityName)"
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            Spacer()
            Label("Open Iqamah", systemImage: "arrow.up.right")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activityGold.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: "clock")
                    .foregroundStyle(activityGold)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayedNextPrayerName(context))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(activityGold)
                    Text(context.state.nextPrayerTime.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
                Text(context.state.nextPrayerTime, style: .relative)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .center, spacing: 4) {
                CrescentView(phase: context.state.moonPhase, size: 24)
                Text(shortHijri(context.state.hijriDateString))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 50)
            .padding(.leading, 4)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func shortHijri(_ full: String) -> String {
        let parts = full.split(separator: " ")
        guard parts.count >= 3 else { return full }
        return "\(parts[0]) \(parts[1])\n\(parts[2])"
    }
}
#endif
