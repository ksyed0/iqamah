#if os(visionOS)
    import ARKit
    import RealityKit
    import SwiftUI

    // MARK: - Volumetric Qibla view (AC-0392–AC-0397)

//
    // Appears as a RealityKit volume (not a 2D compass). A crescent-topped arrow
    // points toward Makkah once the user has calibrated by facing North.
    // The volumetric WindowGroup constrains rotation — users can only translate it —
    // so setting the entity orientation once at calibration time is stable.

    struct QiblaVolumeView: View {
        @ObservedObject private var settings = SettingsManager.shared
        @StateObject private var calibration = QiblaCalibrationState()
        @State private var arrowEntity: Entity?

        var body: some View {
            GeometryReader3D { proxy in
                RealityView { content in
                    let arrow = makeArrowEntity()
                    arrowEntity = arrow
                    content.add(arrow)
                    let bearing = bearingCard(proxy: proxy)
                    content.add(bearing)
                } update: { _ in
                    if let dir = calibration.qiblaWorldDirection, let arrow = arrowEntity {
                        let from = SIMD3<Float>(0, 0, 1)
                        arrow.orientation = simd_quatf(from: from, to: dir)
                    }
                }
            }
            .overlay(alignment: .bottom) { calibrationOverlay }
            .task { await calibration.startSession() }
            .onDisappear { calibration.stopSession() }
            .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
                calibration.reapplyBearing(qiblaBearing)
            }
        }

        // MARK: - Calibration overlay

        private var calibrationOverlay: some View {
            VStack(spacing: 12) {
                if let error = calibration.authorizationError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                } else if !calibration.isCalibrated {
                    VStack(spacing: 8) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.appGold)
                            .symbolEffect(.pulse)
                        Text("Face North, then tap to set Qibla direction")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        Button("Set Qibla Direction") {
                            calibration.calibrateNorth(qiblaBearing: qiblaBearing)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!calibration.isSessionRunning)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Calibrated")
                            .font(.subheadline)
                        Spacer()
                        Button("Recalibrate") {
                            calibration.resetCalibration()
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .glassBackgroundEffect()
            .padding(24)
        }

        // MARK: - Bearing card (floating label)

        private func bearingCard(proxy _: GeometryProxy3D) -> Entity {
            Entity()
        }

        // MARK: - Arrow entity

        private func makeArrowEntity() -> Entity {
            let root = Entity()

            // Shaft
            let shaftMesh = MeshResource.generateCylinder(height: 0.25, radius: 0.015)
            var shaftMat = PhysicallyBasedMaterial()
            shaftMat.baseColor = .init(tint: UIColor(Color.appGold))
            let shaft = ModelEntity(mesh: shaftMesh, materials: [shaftMat])
            shaft.position = [0, 0.125, 0]

            // Head cone
            let coneMesh = MeshResource.generateCone(height: 0.08, radius: 0.03)
            var coneMat = PhysicallyBasedMaterial()
            coneMat.baseColor = .init(tint: UIColor(Color.appGold))
            let cone = ModelEntity(mesh: coneMesh, materials: [coneMat])
            cone.position = [0, 0.29, 0]

            // Crescent sphere (simple approximation)
            let crescentMesh = MeshResource.generateSphere(radius: 0.022)
            var crescentMat = PhysicallyBasedMaterial()
            crescentMat.baseColor = .init(tint: UIColor(Color.appGold))
            crescentMat.metallic = .init(floatLiteral: 0.8)
            let crescent = ModelEntity(mesh: crescentMesh, materials: [crescentMat])
            crescent.position = [0, 0.38, 0]

            root.addChild(shaft)
            root.addChild(cone)
            root.addChild(crescent)
            return root
        }

        // MARK: - Qibla bearing (great-circle to Makkah)

        private var qiblaBearing: Double {
            guard let city = settings.loadCity() else { return 0 }
            return Self.computeQiblaBearing(
                lat: city.latitude, lon: city.longitude,
                makkahLat: 21.4225, makkahLon: 39.8262
            )
        }

        static func computeQiblaBearing(lat: Double, lon: Double,
                                        makkahLat: Double, makkahLon: Double) -> Double {
            let φ1 = lat * .pi / 180
            let φ2 = makkahLat * .pi / 180
            let dLon = (makkahLon - lon) * .pi / 180
            let y = sin(dLon) * cos(φ2)
            let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dLon)
            let bearing = atan2(y, x) * 180 / .pi
            return (bearing + 360).truncatingRemainder(dividingBy: 360)
        }
    }
#endif
