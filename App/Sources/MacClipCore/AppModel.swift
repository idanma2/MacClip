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
    public var searchText = ""

    private var monitor: PasteboardMonitor?
    private var hotKeyManager: HotKeyManager?

    public init(historyStore: ClipboardHistoryStore = ClipboardHistoryStore()) {
        self.historyStore = historyStore
    }

    /// What's actually shown in the popup — the full history, or the
    /// subset matching `searchText`. Selection, copy, and remove all index
    /// into this rather than `historyStore.entries` directly, so they can
    /// never point at the wrong row while a filter is narrowing the list.
    ///
    /// Matches against newline-normalized text (same transform the row
    /// view uses to display each entry on one line) — otherwise a search
    /// phrase that visually reads as one line can miss an entry whose
    /// underlying text has a real line break where the display shows a
    /// space, which looks like "search is broken" for exactly the kind of
    /// multi-line pasted text this app spends most of its time holding.
    public var visibleEntries: [ClipboardEntry] {
        guard !searchText.isEmpty else { return historyStore.entries }
        return historyStore.entries.filter {
            $0.text.replacingOccurrences(of: "\n", with: " ").localizedCaseInsensitiveContains(searchText)
        }
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
        searchText = ""
        selectedIndex = 0
        isOverlayVisible = true
    }

    public func hideOverlay() {
        isOverlayVisible = false
    }

    public func selectNext() {
        guard !visibleEntries.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, visibleEntries.count - 1)
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
        guard visibleEntries.indices.contains(selectedIndex) else { return }
        let entry = visibleEntries[selectedIndex]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        hideOverlay()
    }

    public func removeEntry(_ id: UUID) {
        historyStore.remove(id)
        if selectedIndex >= visibleEntries.count {
            selectedIndex = max(0, visibleEntries.count - 1)
        }
    }
}
