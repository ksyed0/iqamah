import SwiftUI
import IqamahCore

/// Renders a crescent moon using SwiftUI Canvas.
/// `phase` is the synodic phase fraction [0=new, 0.5=full, 1=new again].
struct MoonPhaseView: View {
    let phase: Double // 0–1
    let size: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2 - 2
            let cx = size.width / 2
            let cy = size.height / 2

            // Full disc
            let disc = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.fill(disc, with: .color(.white.opacity(0.15)))

            // Illuminated crescent using two overlapping ellipses
            // Phase 0 = new (no illumination), 0.5 = full, 1 = new again
            let illumination = abs(phase - 0.5) * 2 // 0=full, 1=new
            let xOffset = (1.0 - illumination * 2) * r
            let crescentMask = Path { p in
                p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }
            var shadow = Path()
            shadow.addEllipse(in: CGRect(x: cx - r + xOffset, y: cy - r, width: r * 2, height: r * 2))

            // drawLayer isolates the compositing to an offscreen buffer so that
            // destinationOut only erases pixels within this layer, not outside the disc.
            ctx.drawLayer { layerCtx in
                if phase < 0.5 {
                    // Waxing — lit on right: fill disc gold, punch out shadow on left
                    layerCtx.fill(crescentMask, with: .color(.yellow.opacity(0.9)))
                    layerCtx.blendMode = .destinationOut
                    layerCtx.fill(shadow, with: .color(.black))
                } else {
                    // Waning — lit on left: fill shadow gold, punch out disc overlap on right
                    layerCtx.fill(shadow, with: .color(.yellow.opacity(0.9)))
                    layerCtx.blendMode = .destinationOut
                    layerCtx.fill(crescentMask, with: .color(.black))
                }
            }
        }
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.3), in: Circle())
    }
}
