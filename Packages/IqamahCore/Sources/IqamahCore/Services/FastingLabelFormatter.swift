import Foundation

/// Pure helpers for relabeling prayer-name strings when Fasting Mode is active.
/// Consumed by every narrow surface (menu bar, watch, widgets, Live Activity).
public enum FastingLabelFormatter {

    /// Window (in seconds) before a prayer time during which the Suhoor/Iftar
    /// relabel applies. 2 hours per spec.
    private static let relabelWindow: TimeInterval = 2 * 60 * 60

    /// Relabel a prayer name when Fasting Mode is active and the prayer is within 2h.
    /// Returns the original name if any precondition fails (inactive, prohibition,
    /// outside window, or non-Fajr/non-Maghrib prayer).
    public static func relabel(
        prayerName: String,
        prayerTime: Date,
        currentTime: Date,
        state: FastingDayState
    ) -> String {
        guard state.isActive, state.trigger != nil else { return prayerName }

        let newLabel: String
        switch prayerName {
        case "Fajr": newLabel = "Suhoor"
        case "Maghrib": newLabel = "Iftar"
        default: return prayerName
        }

        let secondsUntil = prayerTime.timeIntervalSince(currentTime)
        guard (0...Self.relabelWindow).contains(secondsUntil) else { return prayerName }

        let glyph: String = state.trigger == .autoRamadan ? "🌙" : "🕗"

        return "\(glyph) \(newLabel)"
    }
}
