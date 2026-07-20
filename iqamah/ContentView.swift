import SwiftUI
import IqamahCore

enum AppScreen {
    case splash
    case locationSetup
    case calculationMethod
    case prayerTimes
}

struct ContentView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var currentScreen: AppScreen = .splash
    @State private var showLegacyReDetectPrompt = false
    @State private var moveDetected: MoveDetectedPayload?
    @State private var selectedCity: City?
    @State private var calculationMethod: CalculationMethod = .muslimWorldLeague
    @State private var asrMethod: AsrJuristicMethod = .standard

    // Uncomment the line below to show icon exporter
    // @State private var showIconExporter = true

    var body: some View {
        Group {
            switch currentScreen {
            case .splash:
                SplashScreenView()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            loadSavedSettingsAndProceed()
                        }
                    }
                    .onAppear {
                        let delay: Double = settings.hasCompletedSetup ? 1.0 : 5.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                loadSavedSettingsAndProceed()
                            }
                        }
                    }

            case .locationSetup:
                LocationSetupView(
                    onLocationConfirmed: { city in
                        selectedCity = city
                        currentScreen = .calculationMethod
                    }
                    // No Back button on the first step of first-run onboarding
                )

            case .calculationMethod:
                CalculationMethodView(
                    selectedMethod: $calculationMethod,
                    selectedAsrMethod: $asrMethod,
                    onConfirm: {
                        if let city = selectedCity {
                            settings.completeSetup(
                                city: city,
                                calculationMethod: calculationMethod,
                                asrMethod: asrMethod
                            )
                        }
                        currentScreen = .prayerTimes
                    },
                    onBack: {
                        currentScreen = .locationSetup
                    }
                )

            case .prayerTimes:
                if let city = selectedCity {
                    PrayerTimesView(
                        city: city,
                        calculationMethod: calculationMethod,
                        asrMethod: asrMethod,
                        onSettingsSaved: { newCity, newMethod, newAsr in
                            selectedCity = newCity
                            calculationMethod = newMethod
                            asrMethod = newAsr
                            // Persist without resetting prayer adjustments
                            settings.completeSetup(
                                city: newCity,
                                calculationMethod: newMethod,
                                asrMethod: newAsr
                            )
                        }
                    )
                }
            }
        }
        .animation(.easeInOut, value: currentScreen)
        // UI scale: double-frame technique — inner frame gives content a fixed
        // logical canvas; scaleEffect scales the pixels; outer frame tells the
        // layout system the true visual footprint so the window resizes to match.
        // Step 1: pin content to exact base canvas — prevents expansion into window.
        .frame(width: 620, height: 680)
        // Step 2: scale from centre so content stays symmetrically positioned.
        //         .topLeading causes the content to push toward that corner,
        //         collapsing the right/bottom border at higher scale values.
        .scaleEffect(settings.uiScale, anchor: .center)
        // Step 3: outer frame = exact visual footprint (620*scale × 680*scale).
        .frame(width: 620 * settings.uiScale, height: 680 * settings.uiScale)
        // Step 4: fixed 10 pt border on every side — this sits OUTSIDE the scale
        //         transform so it never grows or shrinks with the UI.
        .padding(10)
        .background(IqamahBackground())
        .onAppear {
            if settings.isLegacyV15User, !settings.didShowGPSReDetectPromptV16 {
                showLegacyReDetectPrompt = true
            }
        }
        .alert("Location accuracy improved", isPresented: $showLegacyReDetectPrompt) {
            Button("Re-detect") {
                settings.didShowGPSReDetectPromptV16 = true
                NotificationCenter.default.post(name: .openSettingsForReDetect, object: nil)
            }
            Button("Keep current", role: .cancel) {
                settings.didShowGPSReDetectPromptV16 = true
                settings.locationSource = "manual"
            }
        } message: {
            Text(
                "Iqamah v1.6 uses your exact GPS position and authoritative timezone for prayer-time calculations. Re-detect your location now to apply the improvement?"
            )
        }
        // BUG-0069: launch-time auto-detect prompt
        .onReceive(NotificationCenter.default.publisher(for: .didDetectMove)) { note in
            if let payload = note.object as? MoveDetectedPayload {
                moveDetected = payload
            }
        }
        .alert(
            "Have you moved?",
            isPresented: Binding(
                get: { moveDetected != nil },
                set: {
                    if !$0 {
                        moveDetected = nil
                    }
                }
            ),
            presenting: moveDetected
        ) { payload in
            Button("Switch") {
                let locality = payload.detectedLocality.isEmpty
                    ? payload.savedCityName
                    : payload.detectedLocality
                if let newCity = try? City(
                    name: locality,
                    countryCode: settings.loadCity()?.countryCode ?? "US",
                    latitude: payload.detectedCoordinate.latitude,
                    longitude: payload.detectedCoordinate.longitude,
                    timezone: TimeZone.current.identifier
                ) {
                    settings.saveCity(newCity)
                    settings.locationSource = "gps"
                    settings.saveGPSCoordinates(payload.detectedCoordinate)
                    settings.gpsLocality = payload.detectedLocality
                    settings.gpsDetectedCity = newCity
                    selectedCity = newCity
                    NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                }
                moveDetected = nil
            }
            Button("Not now", role: .cancel) {
                moveDetected = nil
            }
        } message: { payload in
            let whereText = payload.detectedLocality.isEmpty
                ? "your current location"
                : payload.detectedLocality
            Text(
                "It looks like you're in \(whereText), about \(payload.distanceKmString) from \(payload.savedCityName). Switch your prayer-times city?"
            )
        }
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    private func loadSavedSettingsAndProceed() {
        if settings.hasCompletedSetup, let savedCity = settings.loadCity() {
            selectedCity = savedCity
            calculationMethod = settings.calculationMethod
            asrMethod = settings.asrMethod
            currentScreen = .prayerTimes
        } else {
            currentScreen = .locationSetup
        }
    }
}

#if DEBUG

    // MARK: - Developer-only icon export tooling (not in Release builds)

//
    // `AppIconView`, `MinaretShape`, the export extension, and `IconExporterView`
    // below are dev tools used to generate app-icon PNGs for the Asset Catalog.
    // They write to ~/Desktop and are not part of the shipping app.
    // See scripts/export-watch-icon.swift for the CLI equivalent.

    // swiftlint:disable force_unwrapping function_body_length
    // MARK: - App Icon View

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
                            Color(red: 0.08, green: 0.15, blue: 0.25),
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
                                    Color.appGoldDim,
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
                                    Color.appGoldDim,
                                    Color(red: 0.85, green: 0.65, blue: 0.13),
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

    // MARK: - Icon Export Utility

    extension AppIconView {
        /// Generate an NSImage at a specific size.
        /// Uses `ImageRenderer` with `scale = 1.0` so output is `size`×`size`
        /// pixels at 72 DPI regardless of host display backing-scale — avoids the
        /// retina-DPI hazard that triggered the BUG-0068 asset-compiler mismatch.
        static func generateImage(size: CGFloat) -> NSImage? {
            let view = AppIconView(size: size, showBackground: true)
                .frame(width: size, height: size)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1.0
            return renderer.nsImage
        }

        /// Export all icon sizes to Desktop
        static func exportIconsToDesktop() {
            // Try multiple locations
            let fileManager = FileManager.default

            // Try Desktop first
            var iconsFolder = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
                .appendingPathComponent("IqamahAppIcons")

            // If Desktop doesn't work, try Documents
            var success = (try? fileManager.createDirectory(at: iconsFolder, withIntermediateDirectories: true)) != nil

            if !success {
                print("⚠️ Cannot write to Desktop, trying Documents...")
                iconsFolder = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("IqamahAppIcons")
                success = (try? fileManager.createDirectory(at: iconsFolder, withIntermediateDirectories: true)) != nil
            }

            if !success {
                print("❌ Cannot create directory")
                return
            }

            print("📁 Saving to: \(iconsFolder.path)")

            let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
            var exportedCount = 0

            for size in sizes {
                if let icon = generateImage(size: size) {
                    let filename = "icon_\(Int(size))x\(Int(size)).png"
                    let fileURL = iconsFolder.appendingPathComponent(filename)

                    if let tiffData = icon.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        do {
                            try pngData.write(to: fileURL)
                            print("✅ Exported: \(filename) to \(fileURL.path)")
                            exportedCount += 1
                        } catch {
                            print("❌ Failed to write \(filename): \(error.localizedDescription)")
                        }
                    }
                }
            }

            if exportedCount > 0 {
                print("🎉 \(exportedCount) icons exported to: \(iconsFolder.path)")
                // Open the folder in Finder
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: iconsFolder.path)
            } else {
                print("❌ No icons were exported")
            }
        }
    }

    // MARK: - Icon Exporter View (for testing/exporting)

    struct IconExporterView: View {
        @State private var exported = false
        @State private var watchExportedVariant: WatchIconVariant?
        @State private var exportPath = ""
        @Environment(\.dismiss) var dismiss

        var body: some View {
            VStack(spacing: 24) {
                Text("Export App Icons")
                    .font(.title)
                    .fontWeight(.bold)

                // iOS / macOS icon preview
                AppIconView(size: 200, showBackground: true)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .shadow(radius: 10)

                Button(action: {
                    let fileManager = FileManager.default
                    let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
                    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                    if fileManager.isWritableFile(atPath: desktopURL.path) {
                        exportPath = desktopURL.appendingPathComponent("IqamahAppIcons").path
                    } else {
                        exportPath = documentsURL.appendingPathComponent("IqamahAppIcons").path
                    }
                    AppIconView.exportIconsToDesktop()
                    exported = true
                }) {
                    Label(exported ? "iOS Icons Exported" : "Export iOS Icons",
                          systemImage: exported ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.headline)
                        .frame(width: 280)
                }
                .buttonStyle(.borderedProminent)
                .disabled(exported)

                Divider().padding(.horizontal, 40)

                // BUG-0068 — watch icon variants
                Text("Watch Icon Variants — BUG-0068")
                    .font(.headline)
                HStack(spacing: 16) {
                    ForEach(WatchIconVariant.allCases) { variant in
                        VStack(spacing: 6) {
                            WatchAppIconView(size: 80, variant: variant)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(watchExportedVariant == variant ? Color.green : Color.clear, lineWidth: 3)
                                )
                            Text(variant.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(spacing: 8) {
                    ForEach(WatchIconVariant.allCases) { variant in
                        Button(action: {
                            WatchAppIconView.exportVariantToDesktop(variant)
                            watchExportedVariant = variant
                        }) {
                            Label("Export Watch — \(variant.label)",
                                  systemImage: watchExportedVariant == variant ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .frame(width: 280)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(action: {
                        WatchAppIconView.exportAllVariantsToDesktop()
                        watchExportedVariant = .radialGlow
                    }) {
                        Label("Export ALL Watch Variants",
                              systemImage: "square.and.arrow.down.on.square")
                            .frame(width: 280)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }

                if exported || watchExportedVariant != nil {
                    VStack(spacing: 4) {
                        Text("✅ Exported")
                            .foregroundColor(.green)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Button("Open Watch Icons Folder in Finder") {
                            let path = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                                .appendingPathComponent("IqamahWatchIcons").path
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(width: 540, height: 760)
        }
    }

    // MARK: - Preview to Export Icons

    #Preview("Icon Exporter") {
        IconExporterView()
    }
    // swiftlint:enable force_unwrapping function_body_length
#endif // DEBUG
