#if os(macOS)
    import AppKit
    import IqamahCore
    import MapKit
    import SwiftUI

    /// Pre-share resolution dialog → NSSharingServicePicker (macOS only).
    struct HilalShareSheet: View {
        let grid: ContiguousArray<Int8>
        let monthLabel: String
        let criterionName: String
        @State private var hiRes = false
        @State private var isExporting = false
        @State private var errorMessage: String?
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            VStack(spacing: 16) {
                Text("Share Hilal Map")
                    .font(.headline)

                Toggle("Hi-res (3072 × 2304)", isOn: $hiRes)
                    .toggleStyle(.checkbox)

                if let err = errorMessage {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.escape)
                    Spacer()
                    Button(isExporting ? "Generating…" : "Share") {
                        Task { await exportAndShare() }
                    }
                    .disabled(isExporting)
                    .keyboardShortcut(.return)
                }
            }
            .padding(24)
            .frame(width: 280)
        }

        private func exportAndShare() async {
            isExporting = true
            defer { isExporting = false }

            let size = hiRes
                ? CGSize(width: 3072, height: 2304)
                : CGSize(width: 1024, height: 768)

            guard let image = await renderSnapshot(size: size) else {
                errorMessage = "Could not generate map snapshot."
                return
            }

            // Write to temp file
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Hilal-\(Date().timeIntervalSince1970).png")
            guard let data = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: data),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                errorMessage = "Could not encode image."
                return
            }
            try? pngData.write(to: url)

            await MainActor.run {
                let picker = NSSharingServicePicker(items: [url])
                if let window = NSApp.windows.first(where: { $0.isKeyWindow }),
                   let view = window.contentView {
                    picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
                }
                dismiss()
            }
        }

        private func renderSnapshot(size: CGSize) async -> NSImage? {
            // Render grid cells as coloured rectangles on a white background
            let image = NSImage(size: size)
            image.lockFocus()
            defer { image.unlockFocus() }

            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()

            let cellW = size.width / CGFloat(HilalCalculator.longitudeBands)
            let cellH = size.height / CGFloat(HilalCalculator.latitudeBands)

            for latBand in 0 ..< HilalCalculator.latitudeBands {
                for lonBand in 0 ..< HilalCalculator.longitudeBands {
                    let idx = latBand * HilalCalculator.longitudeBands + lonBand
                    let rawVal = grid[idx]
                    let cat = VisibilityCategory(rawValue: Int(rawVal)) ?? .D
                    let color: NSColor = switch cat {
                    case .A: NSColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 0.7)
                    case .B: NSColor(red: 0.00, green: 0.50, blue: 0.50, alpha: 0.7)
                    case .C: NSColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 0.5)
                    case .D: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 0.3)
                    }
                    color.setFill()
                    // Flip Y axis (lat 0 = top of image = +88°)
                    let flippedLat = HilalCalculator.latitudeBands - 1 - latBand
                    let rect = CGRect(
                        x: CGFloat(lonBand) * cellW,
                        y: CGFloat(flippedLat) * cellH,
                        width: cellW,
                        height: cellH
                    )
                    rect.fill()
                }
            }

            // Footer
            let footer = "Iqamah · Hilal Watch · \(monthLabel) · \(criterionName)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(10, size.height * 0.015)),
                .foregroundColor: NSColor.darkGray,
            ]
            let attrStr = NSAttributedString(string: footer, attributes: attrs)
            let textSize = attrStr.size()
            attrStr.draw(at: CGPoint(x: 8, y: 8))
            _ = textSize // suppress warning

            return image
        }
    }
#endif
