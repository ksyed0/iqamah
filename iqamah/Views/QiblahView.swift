import SwiftUI

struct QiblahView: View {
    let latitude: Double
    let longitude: Double
    let cityName: String // AC-0134

    private let kaabahLat = 21.4225
    private let kaabahLon = 39.8262

    private var qiblahBearing: Double {
        let lat1 = latitude * .pi / 180
        let lat2 = kaabahLat * .pi / 180
        let deltaLon = (kaabahLon - longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private var cardinalDirection: String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return directions[Int((qiblahBearing + 22.5).truncatingRemainder(dividingBy: 360) / 45)]
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Qiblah Direction")
                .font(.title2.bold())
                .padding(.top, 28)
                .accessibilityAddTraits(.isHeader)

            Text(String(format: "%.1f° %@", qiblahBearing, cardinalDirection))
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.top, 6)
                .accessibilityLabel("Qiblah: \(Int(qiblahBearing)) degrees \(cardinalDirection)")

            // AC-0134: city context — use .secondary (no manual opacity, meets contrast floor)
            if !cityName.isEmpty {
                Text("from \(cityName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            // Compass
            ZStack {
                // ── Compass face: subtle dark disc gives depth ──────────
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 310, height: 310)

                // ── Outer ring: thick + prominent ───────────────────────
                Circle()
                    .stroke(Color.primary.opacity(0.35), lineWidth: 3)
                    .frame(width: 310, height: 310)

                // ── Inner gold decorative ring ───────────────────────────
                Circle()
                    .stroke(
                        Color.appGold.opacity(0.40),
                        lineWidth: 1
                    )
                    .frame(width: 294, height: 294)

                // ── Tick marks: 24 total (every 15°), cardinals prominent ─
                ForEach(0 ..< 24, id: \.self) { i in
                    let angle = Double(i) * 15
                    let isCardinal = i % 6 == 0 // N/E/S/W
                    let isMinorCard = i % 3 == 0 // NE/SE/SW/NW
                    Rectangle()
                        .fill(isCardinal
                            ? Color.primary.opacity(0.85)
                            : isMinorCard
                            ? Color.primary.opacity(0.50)
                            : Color.secondary.opacity(0.30))
                        .frame(width: isCardinal ? 2.5 : isMinorCard ? 1.5 : 1,
                               height: isCardinal ? 18 : isMinorCard ? 12 : 6)
                        .offset(y: -148)
                        .rotationEffect(.degrees(angle))
                        .accessibilityHidden(true)
                }

                // ── Cardinal labels ─────────────────────────────────────
                ForEach([("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)], id: \.0) { label, angle in
                    Text(label)
                        .font(.footnote.bold())
                        .foregroundColor(label == "N" ? Color(red: 0.95, green: 0.30, blue: 0.25) : .primary.opacity(0.7))
                        .offset(x: 170 * sin(angle * .pi / 180),
                                y: -170 * cos(angle * .pi / 180))
                        .accessibilityHidden(true)
                }

                // ── Centre dot ──────────────────────────────────────────
                Circle()
                    .fill(Color.appGold)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                // ── Direction line: graduated green, prominent ───────────
                LinearGradient(
                    colors: [Color.clear, Color(red: 0.15, green: 0.80, blue: 0.35)],
                    startPoint: .bottom, endPoint: .top
                )
                .frame(width: 3, height: 155)
                .offset(y: -77)
                .rotationEffect(.degrees(qiblahBearing))
                .accessibilityHidden(true)

                // ── Prayer mat: enlarged from 40×60 → 64×96 ─────────────
                Image("PrayerMat")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 96)
                    .drawingGroup()
                    .rotationEffect(.degrees(qiblahBearing))
                    .accessibilityLabel("Prayer mat pointing toward Qiblah")

                // ── Ka'bah icon on ring ──────────────────────────────────
                Image("KaabahIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .drawingGroup()
                    .clipShape(Circle())
                    .overlay(Circle().stroke(
                        Color.appGold, lineWidth: 2
                    ))
                    .shadow(color: Color.appGold.opacity(0.5),
                            radius: 4, x: 0, y: 0)
                    .offset(
                        x: 155 * CGFloat(sin(qiblahBearing * .pi / 180)),
                        y: -155 * CGFloat(cos(qiblahBearing * .pi / 180))
                    )
                    .accessibilityLabel("Ka'bah direction indicator")
            }
            .frame(width: 380, height: 380)
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Qiblah compass: \(Int(qiblahBearing))° \(cardinalDirection)")

            Spacer()

            // BUG-0027: gold tint matches app brand instead of default system accent
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.appGold)
                .controlSize(.regular)
                .padding(.bottom, 24)
        }
        .frame(width: 440, height: 560)
        .background {
            if #available(macOS 26, *) {
                Rectangle().glassEffect()
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
    }
}

// MARK: - Ka'bah Marker

/// A small gold-outlined cube representing the Ka'bah on the compass ring.
private struct KaabahMarker: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.15, green: 0.12, blue: 0.08))
                .frame(width: 20, height: 20)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.68, blue: 0.25), lineWidth: 1.5)
                .frame(width: 20, height: 20)
            // Kiswa gold band
            Rectangle()
                .fill(Color(red: 0.85, green: 0.68, blue: 0.25).opacity(0.6))
                .frame(width: 20, height: 3)
                .offset(y: -3)
        }
    }
}

// MARK: - Kaabah Shape (kept for backwards compatibility)

struct KaabahShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.addRoundedRect(
            in: CGRect(x: 0, y: h * 0.1, width: w, height: h * 0.9),
            cornerSize: CGSize(width: w * 0.08, height: w * 0.08)
        )
        path.addRect(CGRect(x: 0, y: h * 0.35, width: w, height: h * 0.12))
        path.addRect(CGRect(x: -w * 0.03, y: h * 0.08, width: w * 1.06, height: h * 0.06))
        return path
    }
}

// MARK: - Prayer Mat Shape (kept for backwards compatibility / other uses)

struct PrayerMatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cornerRadius = w * 0.1
        let archHeight = h * 0.25
        let archWidth = w * 0.5
        path.move(to: CGPoint(x: cornerRadius, y: h))
        path.addLine(to: CGPoint(x: w - cornerRadius, y: h))
        path.addQuadCurve(to: CGPoint(x: w, y: h - cornerRadius), control: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w, y: cornerRadius))
        path.addQuadCurve(to: CGPoint(x: w - cornerRadius, y: 0), control: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w / 2 + archWidth / 2, y: 0))
        path.addCurve(to: CGPoint(x: w / 2, y: archHeight),
                      control1: CGPoint(x: w / 2 + archWidth * 0.4, y: 0),
                      control2: CGPoint(x: w / 2 + archWidth * 0.15, y: archHeight))
        path.addCurve(to: CGPoint(x: w / 2 - archWidth / 2, y: 0),
                      control1: CGPoint(x: w / 2 - archWidth * 0.15, y: archHeight),
                      control2: CGPoint(x: w / 2 - archWidth * 0.4, y: 0))
        path.addLine(to: CGPoint(x: cornerRadius, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: cornerRadius), control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: cornerRadius, y: h), control: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Prayer Mat Icon (header button)

struct PrayerMatIcon: View {
    var size: CGFloat = 20
    var body: some View {
        Image("PrayerMat")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * 0.65, height: size)
    }
}
