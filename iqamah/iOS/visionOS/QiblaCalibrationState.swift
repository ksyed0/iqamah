#if os(visionOS)
    import ARKit
    import Combine
    import Foundation
    import simd

    // MARK: - ARKit-backed Qibla calibration state (AC-0392–AC-0397)

//
    // Vision Pro has no magnetometer; CLLocationManager.headingAvailable returns false.
    // Instead: user taps "Face North" once, we capture the device's forward vector in
    // ARKit world space. The Qibla arrow is then oriented in that world space and remains
    // fixed — volumetric windows can be translated but not rotated by the user, so the
    // arrow keeps pointing toward Makkah without live tracking.

    @MainActor
    final class QiblaCalibrationState: ObservableObject {
        @Published var isCalibrated: Bool = false
        @Published var isSessionRunning: Bool = false
        @Published var authorizationError: String?

        // World-space forward vector captured when user faced North.
        private(set) var northWorldForward: SIMD3<Float>?

        // The computed world-space direction toward Makkah (set after calibration).
        private(set) var qiblaWorldDirection: SIMD3<Float>?

        private var session: ARKitSession?
        private var worldTracking: WorldTrackingProvider?

        private static let defaultsKey = "visionOS.qiblaNorthForward"

        // MARK: - Session lifecycle

        func startSession() async {
            guard WorldTrackingProvider.isSupported else {
                authorizationError = "World tracking is not supported on this device."
                return
            }
            let tracking = WorldTrackingProvider()
            let arSession = ARKitSession()
            worldTracking = tracking
            session = arSession
            do {
                try await arSession.run([tracking])
                isSessionRunning = true
                loadPersistedCalibration()
            } catch {
                authorizationError = error.localizedDescription
            }
        }

        func stopSession() {
            session = nil
            worldTracking = nil
            isSessionRunning = false
        }

        // MARK: - Calibration

        /// Call when the user confirms they are facing North.
        func calibrateNorth(qiblaBearing: Double) {
            guard let tracking = worldTracking else { return }
            let anchor = tracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
            guard let anchor else { return }

            let col2 = anchor.originFromAnchorTransform.columns.2
            // Device forward is -Z column; project to horizontal plane and normalize.
            let rawForward = SIMD3<Float>(-col2.x, 0, -col2.z)
            guard length(rawForward) > 0.001 else { return }
            let north = normalize(rawForward)
            northWorldForward = north

            applyQiblaBearing(qiblaBearing, north: north)
            isCalibrated = true

            UserDefaults.standard.set([north.x, north.y, north.z], forKey: Self.defaultsKey)
        }

        func resetCalibration() {
            isCalibrated = false
            northWorldForward = nil
            qiblaWorldDirection = nil
            UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
        }

        // MARK: - Private helpers

        private func loadPersistedCalibration() {
            guard let stored = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [Float],
                  stored.count == 3
            else { return }
            let north = SIMD3<Float>(stored[0], stored[1], stored[2])
            northWorldForward = north
            // Qibla bearing unknown at load time; caller must call reapplyBearing.
            isCalibrated = true
        }

        /// Recompute the Qibla direction after settings change (e.g. city update).
        func reapplyBearing(_ bearing: Double) {
            guard let north = northWorldForward else { return }
            applyQiblaBearing(bearing, north: north)
        }

        private func applyQiblaBearing(_ bearing: Double, north: SIMD3<Float>) {
            let rad = Float(bearing) * .pi / 180.0
            // Rotate the North vector clockwise by bearing around world Y axis.
            let qiblaDir = SIMD3<Float>(
                cos(rad) * north.x + sin(rad) * north.z,
                0,
                -sin(rad) * north.x + cos(rad) * north.z
            )
            qiblaWorldDirection = length(qiblaDir) > 0.001 ? normalize(qiblaDir) : north
        }
    }
#endif
