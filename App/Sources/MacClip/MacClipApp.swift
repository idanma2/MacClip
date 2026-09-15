import SwiftUI

@main
struct MacClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only presence (no Dock icon — see AppDelegate's
        // `.accessory` activation policy) so the user always has a visible,
        // discoverable way to open history, clear it, or quit, even though
        // day-to-day use is entirely through the ⌥V hotkey.
        MenuBarExtra("MacClip", systemImage: "doc.on.clipboard") {
            Button("Show History (⌥V)") { appDelegate.model.toggleOverlay() }
            Divider()
            Button("Clear History") { appDelegate.model.historyStore.clear() }
            Divider()
            Button("Quit MacClip") { NSApplication.shared.terminate(nil) }
        }
    }
}
