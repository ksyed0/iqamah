import AppKit
import SwiftUI
import Combine

/// Manages the floating adhaan notification panel that slides down from the menu bar.
///
/// The panel uses NSWindowStyleMask.nonactivatingPanel so it never steals keyboard
/// focus or changes the frontmost application — critical for a menu-bar-only agent.
@MainActor
final class AdhaanBannerController {
    static let shared = AdhaanBannerController()

    private var panel: NSPanel?
    private var playerCancellable: AnyCancellable?
    private var isVisible = false

    private init() {}

    // MARK: - Public API

    /// Show the banner for a prayer. Only called when adhaan.id starts with "adhaan_"
    /// (full recordings) — not for alert tones or silent.
    func show(
        prayerName: String,
        prayerTime: Date,
        adhaan: Adhaan,
        allPrayers: [(name: String, time: Date)],
        timezone: TimeZone
    ) {
        // Dismiss any existing banner first
        hide(animated: false)

        let bannerView = AdhaanBannerView(
            prayerName: prayerName,
            prayerTime: prayerTime,
            adhaanDisplayName: adhaan.displayName,
            allPrayers: allPrayers.filter { $0.name != "Sunrise" },
            timezone: timezone,
            onStop: {
                AdhaaanPlayer.shared.stop()
                // Button transitions to CLOSE automatically via isPlaying → false
            },
            onClose: { [weak self] in
                self?.hide(animated: true)
            }
        )

        let hosting = NSHostingView(rootView: bannerView)
        hosting.autoresizingMask = [.width, .height]

        // Size the panel to fit the view
        let bannerWidth: CGFloat = 440
        hosting.frame = CGRect(x: 0, y: 0, width: bannerWidth, height: 1)
        hosting.layoutSubtreeIfNeeded()
        let fittingHeight = hosting.fittingSize.height
        let bannerSize = CGSize(width: bannerWidth, height: max(fittingHeight, 180))

        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: bannerSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.contentView = hosting
        newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        positionPanel(newPanel, size: bannerSize, animated: true)
        panel = newPanel

        // Auto-transition to CLOSE when playback ends naturally
        // Combine publisher operators: .filter + .first() are Publisher methods, not Collection
        // swiftlint:disable:next first_where
        playerCancellable = AdhaaanPlayer.shared.$isPlaying
            .dropFirst()
            .filter { !$0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // isPlaying flipped to false — banner view already shows CLOSE button;
                // no extra action needed here, user closes manually
            }
    }

    func hide(animated: Bool = true) {
        guard let panel else { return }
        playerCancellable?.cancel()
        playerCancellable = nil

        if animated {
            guard let screen = NSScreen.main else {
                panel.orderOut(nil)
                self.panel = nil
                return
            }
            let offScreenY = screen.frame.maxY + 10
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(
                    NSRect(x: panel.frame.origin.x, y: offScreenY,
                           width: panel.frame.width, height: panel.frame.height),
                    display: true
                )
            } completionHandler: { [weak self] in
                panel.orderOut(nil)
                // completionHandler is @Sendable but always fires on main thread;
                // MainActor.assumeIsolated asserts that without a dispatch overhead.
                MainActor.assumeIsolated { self?.panel = nil }
            }
        } else {
            panel.orderOut(nil)
            self.panel = nil
        }
    }

    // MARK: - Private

    private func positionPanel(_ panel: NSPanel, size: CGSize, animated: Bool) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let menuBarHeight: CGFloat = screenFrame.height - screen.visibleFrame.height
            - screen.visibleFrame.origin.y

        let centreX = screenFrame.midX - size.width / 2
        let finalY = screenFrame.maxY - menuBarHeight - size.height - 12
        let startY = screenFrame.maxY + 10 // above screen, hidden

        panel.setFrame(
            NSRect(x: centreX, y: startY, width: size.width, height: size.height),
            display: false
        )
        panel.orderFront(nil)

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.45
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
                panel.animator().setFrame(
                    NSRect(x: centreX, y: finalY, width: size.width, height: size.height),
                    display: true
                )
            }
        } else {
            panel.setFrame(
                NSRect(x: centreX, y: finalY, width: size.width, height: size.height),
                display: true
            )
        }
    }
}
