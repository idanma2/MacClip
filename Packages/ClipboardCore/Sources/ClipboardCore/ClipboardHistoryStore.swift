import Foundation
import Observation

/// Persists text clipboard history to `Application Support`. Newest first.
///
/// Every mutation is written immediately, not just at quit — surviving a
/// crash or force-quit matters more than the cost of a few KB of JSON on
/// each change.
@MainActor
@Observable
public final class ClipboardHistoryStore {
    public private(set) var entries: [ClipboardEntry] = []
    private let maxEntries: Int
    private let fileURL: URL

    public init(fileURL: URL? = nil, maxEntries: Int = 200) {
        self.maxEntries = maxEntries
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = base.appendingPathComponent("MacClip", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("history.json")
        }
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return } // no file yet — first launch, nothing to lose
        guard let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else {
            // Genuinely unreadable, not just "no file yet." Never let a
            // decode failure silently proceed into an empty in-memory list
            // that the next save would then write over the real file —
            // preserve the original bytes instead. See ClipboardEntry's
            // doc comment for why this specific failure mode matters.
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("history.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            return
        }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Records a new copy. Two dedup rules, both matching how every real
    /// clipboard manager behaves:
    /// - Copying the exact same text twice in a row is a no-op — nothing
    ///   new to show, and it would otherwise spam the top of the list.
    /// - Copying text that already exists further down the history moves
    ///   that existing entry back to the top rather than leaving a stale
    ///   duplicate sitting where it was.
    public func record(text: String) {
        guard !text.isEmpty else { return }
        guard entries.first?.text != text else { return }
        entries.removeAll { $0.text == text }
        entries.insert(ClipboardEntry(text: text), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        persist()
    }

    public func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    public func clear() {
        entries.removeAll()
        persist()
    }
}
