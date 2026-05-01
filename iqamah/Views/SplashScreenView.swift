import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background photo (mosque at golden hour, title baked in)
                if let image = loadSplashImage() {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.05, blue: 0.15),
                                 Color(red: 0.10, green: 0.08, blue: 0.20)],
                        startPoint: .top, endPoint: .bottom
                    )
                }

                // SwiftUI overlay: Arabic text centred in the upper title zone
                // (CoreText handles Arabic shaping correctly; PIL cannot)
                VStack(spacing: 0) {
                    Text("إقامة")
                        .font(.system(size: 42, weight: .medium, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.90, green: 0.72, blue: 0.28),
                                         Color(red: 0.72, green: 0.57, blue: 0.18)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        // Sits just below the baked-in "Iqamah" title (~18% from top)
                        .padding(.top, geometry.size.height * 0.18)

                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
    }

    private func loadSplashImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "splash", withExtension: "jpg") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
