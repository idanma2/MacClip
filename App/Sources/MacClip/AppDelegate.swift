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

    private func showOverlay() {
        let panel = overlayPanel ?? OverlayPanel(model: model)
        overlayPanel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func hideOverlay() {
        overlayPanel?.orderOut(nil)
    }
}
