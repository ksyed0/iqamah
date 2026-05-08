import SwiftUI

// MARK: - Sunrise Row (US-0028)

/// Muted info row for Sunrise — not a prayer, no adjustment controls.
struct SunriseRow: View {
    let time: Date
    let formatter: DateFormatter

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "sunrise.fill")
                    .font(.body)
                    .foregroundColor(.secondary) // AC-0063: no opacity reduction on semantic colour
                    .frame(width: 44, height: 36)
                Text("Sunrise")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatter.string(from: time))
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(minWidth: 100, alignment: .trailing)
            Color.clear.frame(width: 76)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sunrise at \(formatter.string(from: time))")
    }
}

// MARK: - Secondary Toolbar Button

/// Flat toolbar-style button used in the secondary bar below the primary header.
/// Matches macOS convention: no border, subtle background on hover only.
struct SecondaryToolbarButton: View {
    let label: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isHovering ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering
                        ? Color(nsColor: .quaternaryLabelColor).opacity(0.5)
                        : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
