import AppKit
import Observation
import MacClipCore

/// Owns the `AppModel` and the `OverlayPanel`'s lifecycle — an
/// `NSApplicationDelegate` rather than pure SwiftUI scenes because the
/// overlay needs precise `NSPanel` control (`.nonactivatingPanel`, floating
/// level, `canBecomeKey`) that SwiftUI's `Window`/`WindowGroup` scenes
/// don't expose.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var overlayPanel: OverlayPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar-only, no Dock icon
        model.start()
        observeOverlayVisibility()
    }

    /// `@Observable` has no Combine publisher of its own — this is the
    /// standard bridge from an `@Observable` property into imperative
    /// AppKit code outside a SwiftUI view body: re-register after every
    /// firing, since `withObservationTracking`'s `onChange` closure fires
    /// exactly once per registration.
    private func observeOverlayVisibility() {
        withObservationTracking {
            _ = model.isOverlayVisible
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.model.isOverlayVisible {
                    self.showOverlay()
                } else {
                    self.hideOverlay()
                }
                self.observeOverlayVisibility()
            }
        }
    }

    /// Pops the panel in with a brief fade + scale-from-center, like
    /// Spotlight/Alfred, rather than the instant `orderFront` AppKit does
    /// by default — `NSWindow.animator()` is the standard way to animate
    /// window properties (`alphaValue`, `frame`) without a `CGEventTap` or
    /// any extra permission.
    private func showOverlay() {
        let panel = overlayPanel ?? OverlayPanel(model: model)
        overlayPanel = panel
        panel.center()

        let finalFrame = panel.frame
        let startFrame = finalFrame.insetBy(dx: finalFrame.width * 0.04, dy: finalFrame.height * 0.04)
        panel.alphaValue = 0
        panel.setFrame(startFrame, display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    private func hideOverlay() {
        guard let panel = overlayPanel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            // AppKit always invokes this on the main thread, but the SDK's
            // closure type isn't `@MainActor`-annotated — `assumeIsolated`
            // documents that guarantee to the compiler instead of hopping
            // queues for something that's already synchronous.
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                panel.alphaValue = 1 // reset for the next fade-in
            }
        })
    }
}
