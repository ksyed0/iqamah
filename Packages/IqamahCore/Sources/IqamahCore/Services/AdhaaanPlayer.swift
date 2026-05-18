import Foundation
import AVFoundation

/// Plays Adhaan audio and manages global mute state.
@MainActor
public class AdhaaanPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AdhaaanPlayer()

    @Published public var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "adhaanMuted") }
    }

    @Published public var isPlaying = false
    @Published public var audioFailed = false

    private var player: AVAudioPlayer?

    override private init() {
        isMuted = UserDefaults.standard.bool(forKey: "adhaanMuted")
    }

    /// Play the Adhaan for a prayer if one is configured and not muted.
    public func play(_ adhaan: Adhaan) {
        guard !isMuted, adhaan.id != "silent", !adhaan.filename.isEmpty else { return }
        startPlayback(adhaan)
    }

    /// Preview an adhaan regardless of mute state (for the settings picker).
    public func preview(_ adhaan: Adhaan) {
        guard adhaan.id != "silent", !adhaan.filename.isEmpty else { return }
        startPlayback(adhaan)
    }

    public func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        audioFailed = false
    }

    public func toggleMute() {
        isMuted.toggle()
        if isMuted { stop() }
    }

    // MARK: - AVAudioPlayerDelegate

    public nonisolated func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.audioFailed = false
            self.player = nil
        }
    }

    // MARK: - Private

    private func startPlayback(_ adhaan: Adhaan) {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let name = (adhaan.filename as NSString).deletingPathExtension
        let ext = (adhaan.filename as NSString).pathExtension

        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
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
                audioFailed = false
            } else {
                print("[AdhaaanPlayer] play() returned false — audio subsystem busy or unavailable")
                audioFailed = true
            }
        } catch {
            print("AdhaaanPlayer: playback error — \(error.localizedDescription)")
        }
    }
}
