import Foundation
import Observation
import AppKit
import ClipboardCore

@MainActor
@Observable
public final class AppModel {
    public let historyStore: ClipboardHistoryStore
    public var isOverlayVisible = false
    public var selectedIndex = 0

    private var monitor: PasteboardMonitor?
    private var hotKeyManager: HotKeyManager?

    public init(historyStore: ClipboardHistoryStore = ClipboardHistoryStore()) {
        self.historyStore = historyStore
    }

    /// Starts clipboard monitoring and registers the global ⌥V hotkey.
    /// Split from `init` so a test can construct an `AppModel` against an
    /// isolated store without also registering a real, process-wide global
    /// hotkey and a real `NSPasteboard.general` poller.
    public func start() {
        let store = historyStore
        let monitor = PasteboardMonitor { text in
            store.record(text: text)
        }
        monitor.start()
        self.monitor = monitor

        let hotKeyManager = HotKeyManager { [weak self] in
            self?.toggleOverlay()
        }
        hotKeyManager.register()
        self.hotKeyManager = hotKeyManager
    }

    public func stop() {
        monitor?.stop()
        monitor = nil
        hotKeyManager?.unregister()
        hotKeyManager = nil
    }

    public func toggleOverlay() {
        if isOverlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    public func showOverlay() {
        selectedIndex = 0
        isOverlayVisible = true
    }

    public func hideOverlay() {
        isOverlayVisible = false
    }

    public func selectNext() {
        guard !historyStore.entries.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, historyStore.entries.count - 1)
    }

    public func selectPrevious() {
        selectedIndex = max(selectedIndex - 1, 0)
    }

    /// Copies the currently selected entry back to the real pasteboard and
    /// hides the overlay. Pasting itself (⌘V) is left to the user — MacClip
    /// fills the pasteboard, it doesn't simulate keystrokes into whatever
    /// app was frontmost, same as how every other clipboard manager's
    /// "select an item" action works.
    public func copySelected() {
        guard historyStore.entries.indices.contains(selectedIndex) else { return }
        let entry = historyStore.entries[selectedIndex]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        hideOverlay()
    }

    public func removeEntry(_ id: UUID) {
        historyStore.remove(id)
        if selectedIndex >= historyStore.entries.count {
            selectedIndex = max(0, historyStore.entries.count - 1)
        }
    }
}
