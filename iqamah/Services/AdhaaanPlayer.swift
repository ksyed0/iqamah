import Foundation
import AVFoundation

/// Plays Adhaan audio and manages global mute state.
@MainActor
class AdhaaanPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AdhaaanPlayer()

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "adhaanMuted") }
    }

    @Published var isPlaying = false

    private var player: AVAudioPlayer?

    override private init() {
        isMuted = UserDefaults.standard.bool(forKey: "adhaanMuted")
    }

    /// Play the Adhaan for a prayer if one is configured and not muted.
    func play(_ adhaan: Adhaan) {
        guard !isMuted, adhaan.id != "silent", !adhaan.filename.isEmpty else { return }
        startPlayback(adhaan)
    }

    /// Preview an adhaan regardless of mute state (for the settings picker).
    func preview(_ adhaan: Adhaan) {
        guard adhaan.id != "silent", !adhaan.filename.isEmpty else { return }
        startPlayback(adhaan)
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted { stop() }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.player = nil
        }
    }

    // MARK: - Private

    private func startPlayback(_ adhaan: Adhaan) {
        let name = (adhaan.filename as NSString).deletingPathExtension
        let ext = (adhaan.filename as NSString).pathExtension

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("AdhaaanPlayer: file not found — \(adhaan.filename)")
            return
        }

        do {
            stop()
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            if newPlayer.play() {
                player = newPlayer
                isPlaying = true
            } else {
                print("AdhaaanPlayer: play() returned false — audio subsystem busy or unavailable")
            }
        } catch {
            print("AdhaaanPlayer: playback error — \(error.localizedDescription)")
        }
    }
}
