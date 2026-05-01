import SwiftUI

import SwiftUI

struct AppIconView: View {
    var size: CGFloat = 1024
    var showBackground: Bool = true
    
    var body: some View {
        ZStack {
            if showBackground {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.25, blue: 0.35),
                        Color(red: 0.08, green: 0.15, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Main content
            VStack(spacing: size * 0.02) {
                // Minaret
                MinaretShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.65, blue: 0.13),
                                Color(red: 0.95, green: 0.76, blue: 0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.35, height: size * 0.45)
                    .shadow(color: Color.black.opacity(0.3), radius: size * 0.02, x: 0, y: size * 0.01)
                
                // Stylized lowercase "i"
                Text("i")
                    .font(.system(size: size * 0.28, weight: .light, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.76, blue: 0.06),
                                Color(red: 0.85, green: 0.65, blue: 0.13)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: size * 0.015, x: 0, y: size * 0.008)
                    .offset(y: -size * 0.03)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

struct MinaretShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Crescent moon on top
        let crescentTop = height * 0.05
        let crescentWidth = width * 0.3
        let crescentHeight = height * 0.08
        let crescentCenter = CGPoint(x: width / 2, y: crescentTop)
        
        path.addArc(
            center: CGPoint(x: crescentCenter.x - crescentWidth * 0.15, y: crescentCenter.y),
            radius: crescentWidth * 0.35,
            startAngle: .degrees(-30),
            endAngle: .degrees(210),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: crescentCenter.x + crescentWidth * 0.05, y: crescentCenter.y),
            radius: crescentWidth * 0.25,
            startAngle: .degrees(150),
            endAngle: .degrees(-70),
            clockwise: true
        )
        
        // Spire (thin pointed top)
        let spireTop = crescentTop + crescentHeight
        let spireBottom = height * 0.18
        let spireWidth = width * 0.08
        
        path.move(to: CGPoint(x: width / 2, y: spireTop))
        path.addLine(to: CGPoint(x: width / 2 - spireWidth / 2, y: spireBottom))
        path.addLine(to: CGPoint(x: width / 2 + spireWidth / 2, y: spireBottom))
        path.closeSubpath()
        
        // Dome/cap
        let domeTop = spireBottom
        let domeBottom = height * 0.28
        let domeWidth = width * 0.45
        
        path.move(to: CGPoint(x: width / 2 - domeWidth / 2, y: domeBottom))
        path.addQuadCurve(
            to: CGPoint(x: width / 2 + domeWidth / 2, y: domeBottom),
            control: CGPoint(x: width / 2, y: domeTop)
        )
        path.addLine(to: CGPoint(x: width / 2 + domeWidth / 2, y: domeBottom))
        path.closeSubpath()
        
        // Balcony (decorative ring)
        let balconyY = domeBottom
        let balconyWidth = width * 0.55
        let balconyHeight = height * 0.04
        
        path.addRoundedRect(
            in: CGRect(
                x: width / 2 - balconyWidth / 2,
                y: balconyY,
                width: balconyWidth,
                height: balconyHeight
            ),
            cornerSize: CGSize(width: balconyHeight * 0.3, height: balconyHeight * 0.3)
        )
        
        // Main tower body (tapered)
        let towerTop = balconyY + balconyHeight
        let towerBottom = height * 0.88
        let towerTopWidth = width * 0.42
        let towerBottomWidth = width * 0.55
        
        path.move(to: CGPoint(x: width / 2 - towerTopWidth / 2, y: towerTop))
        path.addLine(to: CGPoint(x: width / 2 - towerBottomWidth / 2, y: towerBottom))
        path.addLine(to: CGPoint(x: width / 2 + towerBottomWidth / 2, y: towerBottom))
        path.addLine(to: CGPoint(x: width / 2 + towerTopWidth / 2, y: towerTop))
        path.closeSubpath()
        
        // Windows (decorative cutouts represented as arches)
        let windowY1 = height * 0.45
        let windowY2 = height * 0.60
        let windowY3 = height * 0.75
        let windowWidth = width * 0.18
        let windowHeight = height * 0.08
        
        for windowY in [windowY1, windowY2, windowY3] {
            // Left window
            path.move(to: CGPoint(x: width / 2 - windowWidth * 1.2, y: windowY + windowHeight))
            path.addQuadCurve(
                to: CGPoint(x: width / 2 - windowWidth * 1.2 + windowWidth * 0.6, y: windowY + windowHeight),
                control: CGPoint(x: width / 2 - windowWidth * 0.9, y: windowY)
            )
            
            // Right window
            path.move(to: CGPoint(x: width / 2 + windowWidth * 0.6, y: windowY + windowHeight))
            path.addQuadCurve(
                to: CGPoint(x: width / 2 + windowWidth * 1.2, y: windowY + windowHeight),
                control: CGPoint(x: width / 2 + windowWidth * 0.9, y: windowY)
            )
        }
        
        // Base platform
        let baseY = towerBottom
        let baseWidth = width * 0.8
        let baseHeight = height * 0.12
        
        path.addRoundedRect(
            in: CGRect(
                x: width / 2 - baseWidth / 2,
                y: baseY,
                width: baseWidth,
                height: baseHeight
            ),
            cornerSize: CGSize(width: baseHeight * 0.2, height: baseHeight * 0.2)
        )
        
        return path
    }
}

// Preview helper
struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AppIconView(size: 512, showBackground: true)
                .frame(width: 512, height: 512)
            
            AppIconView(size: 256, showBackground: true)
                .frame(width: 256, height: 256)
            
            AppIconView(size: 128, showBackground: true)
                .frame(width: 128, height: 128)
        }
        .padding()
    }
}
