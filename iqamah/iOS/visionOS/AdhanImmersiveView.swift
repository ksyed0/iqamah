#if os(visionOS)
    import RealityKit
    import SwiftUI

    // MARK: - Immersive Space for adhan (AC-0398–AC-0403)

//
    // Mixed immersive space: passthrough AR with ambient particle emitter and
    // spatial adhan audio at (0, 2.5, -1) — a virtual minaret above the user.
    // Auto-dismisses 30 s after adhan finishes. User can also dismiss manually.
//
    // The filename is communicated via @AppStorage("visionOS.adhanFilename") —
    // the banner view writes it before calling openImmersiveSpace.

    struct AdhanImmersiveView: View {
        @AppStorage("visionOS.adhanFilename") private var adhanFilename = "adhan_makkah.mp3"
        @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
        @StateObject private var player = SpatialAdhanPlayer()
        @State private var didStartPlayback = false

        var body: some View {
            RealityView { content in
                content.add(makeParticleEntity())
            }
            .task {
                guard !didStartPlayback else { return }
                didStartPlayback = true
                player.play(filename: adhanFilename) {
                    try? await Task.sleep(for: .seconds(30))
                    await dismissImmersiveSpace()
                }
            }
            .overlay(alignment: .bottom) { dismissButton }
            .onDisappear { player.stop() }
        }

        // MARK: - Dismiss control

        private var dismissButton: some View {
            Button {
                player.stop()
                Task { await dismissImmersiveSpace() }
            } label: {
                Label("End Adhan", systemImage: "xmark.circle.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .padding(32)
            .glassBackgroundEffect()
            .padding(24)
        }

        // MARK: - Ambient particles

        private func makeParticleEntity() -> Entity {
            let entity = Entity()
            var emitter = ParticleEmitterComponent()

            emitter.emitterShape = .sphere
            emitter.birthRate = 40
            emitter.lifeSpan = 4.0
            emitter.speed = 0.05
            emitter.spreadingAngle = 180 * .pi / 180

            emitter.mainEmitter.size = 0.004
            emitter.mainEmitter.color = .constant(.single(.init(red: 1, green: 0.85, blue: 0.4, alpha: 0.6)))
            emitter.mainEmitter.opacityOverLife = .linearFade

            entity.components.set(emitter)
            entity.position = [0, 2.0, -0.5]
            return entity
        }
    }

    // MARK: - Shared scene identifier constants

    enum VisionSceneIDs {
        static let qiblaVolume = "qibla-volume"
        static let adhanImmersive = "adhan-immersive"
    }
#endif
