import SwiftUI
import AppKit

/// Utility to generate app icon images at various sizes
struct AppIconGenerator {
    
    /// Standard macOS app icon sizes
    static let iconSizes: [CGFloat] = [
        16, 32, 64, 128, 256, 512, 1024
    ]
    
    /// Generate an NSImage from the AppIconView
    static func generateIcon(size: CGFloat) -> NSImage? {
        let view = AppIconView(size: size, showBackground: true)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: size, height: size)
        
        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }
        
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)
        
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(bitmapRep)
        
        return image
    }
    
    /// Export all icon sizes to a specified directory
    static func exportIcons(to directoryURL: URL) {
        let fileManager = FileManager.default
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        
        for size in iconSizes {
            if let icon = generateIcon(size: size) {
                let filename = "icon_\(Int(size))x\(Int(size)).png"
                let fileURL = directoryURL.appendingPathComponent(filename)
                
                if let tiffData = icon.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: fileURL)
                    print("✅ Exported: \(filename)")
                }
            }
        }
        
        print("🎉 All icons exported to: \(directoryURL.path)")
    }
    
    /// Export icons to Desktop/IqamahIcons folder
    static func exportIconsToDesktop() {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let iconsFolder = desktopURL.appendingPathComponent("IqamahIcons")
        exportIcons(to: iconsFolder)
    }
}

// Preview window to export icons
struct AppIconExporterView: View {
    @State private var exported = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("App Icon Generator")
                .font(.title)
                .fontWeight(.bold)
            
            AppIconView(size: 256, showBackground: true)
                .frame(width: 256, height: 256)
                .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
                .shadow(radius: 10)
            
            Button(action: {
                AppIconGenerator.exportIconsToDesktop()
                exported = true
            }) {
                Label("Export Icon Files to Desktop", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(exported)
            
            if exported {
                Text("✅ Icons exported to Desktop/IqamahIcons")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
            
            Text("This will generate PNG files at all required sizes:\n16×16, 32×32, 64×64, 128×128, 256×256, 512×512, 1024×1024")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
        .frame(width: 500, height: 600)
    }
}

struct AppIconExporterView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconExporterView()
    }
}
