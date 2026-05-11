import SwiftUI
import IqamahCore

struct LocalSightingCardView: View {
    let values: LocalSightingValues
    let criterionName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Local Sighting")
                    .font(.headline)
                Spacer()
                categoryBadge
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                row("ARCL", value: values.arcl, unit: "°", desc: "Arc of Light")
                row("ARCV", value: values.arcv, unit: "°", desc: "Arc of Vision")
                row("W", value: values.widthArcmin, unit: "′", desc: "Crescent Width")
                row(criterionValueLabel, value: values.criterionValue, unit: "", desc: criterionName)
            }
            visibilityScaleBar
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var criterionValueLabel: String {
        criterionName.hasPrefix("Odeh") ? "V" : "q"
    }

    private var categoryBadge: some View {
        Text(values.category.label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.2), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch values.category {
        case .A: .green
        case .B: .teal
        case .C: .gray
        case .D: .red
        }
    }

    private func row(_ label: String, value: Double, unit: String, desc: String) -> some View {
        GridRow {
            Text(label)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f%@", value, unit))
                .font(.system(.body, design: .monospaced))
            Text(desc)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var visibilityScaleBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Visibility Scale")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(VisibilityCategory.allCases.reversed(), id: \.rawValue) { cat in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cat == values.category ? badgeColor : Color.gray.opacity(0.3))
                        .frame(height: 6)
                }
            }
            HStack {
                Text("Not visible")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Easily visible")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
