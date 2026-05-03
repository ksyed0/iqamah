import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let gold = Color(red: 0.88, green: 0.69, blue: 0.06)

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Hero image ───────────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    if let image = loadSplashImage() {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.05, green: 0.05, blue: 0.15),
                                     Color(red: 0.10, green: 0.08, blue: 0.20)],
                            startPoint: .top, endPoint: .bottom
                        )
                    }

                    // Gradient fade for text legibility
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // App name overlay
                    VStack(spacing: 4) {
                        Text("Iqamah")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.76, blue: 0.06),
                                             Color(red: 0.80, green: 0.60, blue: 0.10)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

                        Text("إقامة")
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundColor(gold.opacity(0.85))
                            .shadow(color: .black.opacity(0.5), radius: 3)
                    }
                    .padding(.bottom, 20)
                }
            }
            .frame(height: 200)

            // ── Content ──────────────────────────────────────────────
            VStack(spacing: 20) {
                // Version
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                // Author
                VStack(spacing: 4) {
                    Text("Implemented by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Kamal Syed")
                        .font(.title3.weight(.semibold))
                }

                // GitHub link
                // Literal URL string — cannot fail to parse
                // swiftlint:disable:next force_unwrapping
                Link(destination: URL(string: "https://github.com/ksyed0/iqamah")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.callout)
                        Text("github.com/ksyed0/iqamah")
                            .font(.callout)
                            .underline()
                    }
                    .foregroundColor(gold)
                }

                Divider()

                // Charity message
                VStack(spacing: 8) {
                    Text("A Free App for the Community")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(
                        "Iqamah is free and open source. If it brings you benefit, please consider " +
                            "donating to a worthy cause in your community — your local mosque, " +
                            "a food bank, or any charity you trust."
                    )
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)

                Divider()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 8)

            // ── Close button ─────────────────────────────────────────
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(gold)
                .controlSize(.regular)
                .keyboardShortcut(.escape, modifiers: [])
                .padding(.bottom, 24)
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func loadSplashImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "splash", withExtension: "jpg") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
