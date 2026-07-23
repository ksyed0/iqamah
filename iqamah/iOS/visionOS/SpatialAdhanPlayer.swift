#if os(visionOS)
    import AVFoundation
    import Foundation

    // MARK: - Spatial adhan audio player (AC-0400)

//
    // Places the adhan at a fixed 3D point above and in front of the user — a minaret
    // metaphor. With AirPods Pro/Max the listener's head orientation is tracked, so
    // the sound stays "above" even as the user turns. Without headphones it falls back
    // to the device speaker with light reverb.

    @MainActor
    final class SpatialAdhanPlayer: ObservableObject {
        @Published var isPlaying: Bool = false

        private let engine = AVAudioEngine()
        private let environment = AVAudioEnvironmentNode()
        private let playerNode = AVAudioPlayerNode()
        private var completionToken: AVAudioPlayerNode.NotificationToken?

        // Minaret position: 2.5 m directly above, 1 m in front of the listener.
        private let minaretPosition = AVAudio3DPoint(x: 0, y: 2.5, z: -1)

        init() {
            engine.attach(environment)
            engine.attach(playerNode)
            engine.connect(environment, to: engine.mainMixerNode, format: nil)
            environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
            environment.reverbParameters.enable = true
            environment.reverbParameters.level = -12 // subtle outdoor reverb
            environment.renderingAlgorithm = .sphericalHead
        }

        // MARK: - Playback

        func play(filename: String, onFinish: @escaping @MainActor () -> Void) {
            guard let url = Bundle.main.url(forResource: filename, withExtension: nil)
                ?? Bundle.main.url(forResource: (filename as NSString).deletingPathExtension,
                                   withExtension: (filename as NSString).pathExtension)
            else { return }

            guard let file = try? AVAudioFile(forReading: url) else { return }

            engine.connect(playerNode, to: environment, format: file.processingFormat)
            playerNode.position = minaretPosition
            playerNode.reverbBlend = 0.25

            try? engine.start()

            playerNode.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isPlaying = false
                    onFinish()
                }
            }
            playerNode.play()
            isPlaying = true
        }

        func stop() {
            playerNode.stop()
            engine.stop()
            isPlaying = false
        }
    }
#endif
