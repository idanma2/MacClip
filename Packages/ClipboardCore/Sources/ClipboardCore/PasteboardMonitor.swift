import Foundation
import AppKit

/// Watches `NSPasteboard.general` for new text copies. `NSPasteboard` has
/// no push/notification API — `changeCount` polling is the standard,
/// only way any clipboard manager on macOS detects a new copy, Apple's own
/// `NSPasteboard` documentation included.
@MainActor
public final class PasteboardMonitor {
    /// The de facto standard (nspasteboard.org) types a source app sets to
    /// tell clipboard managers "don't record this" — 1Password and most
    /// other password managers mark their copies this way specifically so
    /// tools like this one skip them. Concealed = sensitive (passwords,
    /// OTP codes); Transient = not sensitive necessarily, but meant to be
    /// gone once used (e.g. a one-time paste buffer). Respecting both is
    /// table stakes for a real clipboard manager, not optional polish —
    /// found the gap firsthand: an unrelated background app's copy landed
    /// in a test run here before this check existed.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private let pasteboard: NSPasteboard
    private let pollInterval: TimeInterval
    private let onNewText: (String) -> Void
    private var lastChangeCount: Int
    private var timer: Timer?

    public init(pasteboard: NSPasteboard = .general, pollInterval: TimeInterval = 0.5, onNewText: @escaping (String) -> Void) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.onNewText = onNewText
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        let types = pasteboard.types ?? []
        guard !types.contains(Self.concealedType), !types.contains(Self.transientType) else { return }

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        onNewText(text)
    }
}
