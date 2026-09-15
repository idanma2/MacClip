import AppKit
import SwiftUI
import MacClipCore

/// The floating history popup. `.nonactivatingPanel` is the key style bit:
/// it can still become the *key* window (so arrow keys/Enter/Escape reach
/// it) without becoming the frontmost *application* — whatever app the
/// user was in keeps showing as active in the menu bar/Dock behind it,
/// exactly like Spotlight or Alfred's popup behaves.
final class OverlayPanel: NSPanel {
    init(model: AppModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        contentView = NSHostingView(rootView: OverlayContentView(model: model))
    }

    override var canBecomeKey: Bool { true }
}
