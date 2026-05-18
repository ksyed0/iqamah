import SwiftUI
import IqamahCore

struct AboutHilalWatchCard: View {
    @Binding var isPresented: Bool
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif

    var body: some View {
        // On iPad (.regular), expand to 640×740 so all three criteria fit without scrolling.
        // On iPhone, keep the existing 400×500 to avoid overflowing the screen.
        let cardWidth: CGFloat = {
            #if os(iOS)
                return hSizeClass == .regular ? 640 : 400
            #else
                return 400
            #endif
        }()
        let cardHeight: CGFloat = {
            #if os(iOS)
                return hSizeClass == .regular ? 740 : 500
            #else
                return 500
            #endif
        }()
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("About Hilal Watch")
                        .font(.title2.bold())
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                aboutSection(
                    title: "The S-Curve",
                    // swiftlint:disable:next line_length
                    body: "Crescent visibility follows a characteristic S-shaped band across the globe. Near the equator, the crescent is easier to see due to a more vertical ecliptic. At high latitudes, the crescent is often below the horizon or at a shallow angle, making sighting difficult even when geometrically elongated."
                )

                criterionSection(
                    name: "Odeh (2004)",
                    desc: "Uses crescent width W (arcminutes) and arc of vision ARCV. Validated against 737 ICOP observations. Categories A–D based on V = ARCV − f(W).",
                    color: .blue
                )

                criterionSection(
                    name: "Yallop (1997)",
                    desc: "Uses arc of light ARCL and ARCV to compute a q-value. Six categories (A–F) collapsed to A–D. Based on Indian Astronomical Ephemeris tabulations.",
                    color: .purple
                )

                criterionSection(
                    name: "HMNAO Enhanced",
                    desc: "Her Majesty's Nautical Almanac Office refinement of Yallop. Same q-value formula with a simplified 4-category scheme reflecting modern photometric estimates.",
                    color: .indigo
                )

                Text(
                    "Map cells show 2°×2° grid cells. At latitudes above 60°, cells appear stretched due to the Mercator projection — the underlying values remain accurate."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func aboutSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.body).foregroundStyle(.secondary)
        }
    }

    private func criterionSection(name: String, desc: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
