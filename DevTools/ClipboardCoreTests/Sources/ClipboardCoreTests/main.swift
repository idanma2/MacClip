import Foundation
import AppKit
import ClipboardCore

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var total = 0
func expect(_ condition: Bool, _ message: String) {
    total += 1
    if condition {
        print("  ✅ \(message)")
    } else {
        failures += 1
        print("  ❌ \(message)")
    }
}

func tempStoreURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-scenario-\(UUID().uuidString).json")
}

// This suite writes to the REAL NSPasteboard.general — there's no
// sandboxed alternative on macOS. Save whatever's really on it right now
// and restore it once every test has run, so this never leaves the user's
// actual clipboard in a different state than before the run — same
// discipline MacSecureSSH's tests apply to real saved-session files.
@MainActor func captureRealClipboard() -> String? {
    NSPasteboard.general.string(forType: .string)
}
@MainActor func restoreRealClipboard(_ backup: String?) {
    NSPasteboard.general.clearContents()
    if let backup {
        NSPasteboard.general.setString(backup, forType: .string)
    }
}

@MainActor func test_pasteboardMonitor_detectsRealCopy() async {
    print("\n[1] PasteboardMonitor detects a real NSPasteboard write and ClipboardHistoryStore records it")
    let store = ClipboardHistoryStore(fileURL: tempStoreURL())
    let monitor = PasteboardMonitor(pollInterval: 0.05) { text in store.record(text: text) }
    monitor.start()

    let marker = "MACCLIP_TEST_MARKER_\(UUID().uuidString)"
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(marker, forType: .string)
    try? await Task.sleep(for: .milliseconds(300))

    expect(store.entries.first?.text == marker, "the real copy was detected and recorded as the newest entry")
    monitor.stop()
}

@MainActor func test_record_dedupsConsecutiveIdenticalCopies() {
    print("\n[2] Copying the exact same text twice in a row does not create a duplicate row")
    let store = ClipboardHistoryStore(fileURL: tempStoreURL())
    store.record(text: "hello world")
    store.record(text: "hello world")
    expect(store.entries.count == 1, "still exactly one entry after the same text was copied twice in a row")
}

@MainActor func test_record_movesExistingEntryToTopInsteadOfDuplicating() {
    print("\n[3] Re-copying an older entry moves it to the top instead of leaving a stale duplicate")
    let store = ClipboardHistoryStore(fileURL: tempStoreURL())
    store.record(text: "first")
    store.record(text: "second")
    store.record(text: "third")
    expect(store.entries.map(\.text) == ["third", "second", "first"], "sanity: newest first")

    store.record(text: "first") // re-copy the oldest one

    expect(store.entries.count == 3, "still exactly 3 entries, not 4 — no duplicate row")
    expect(store.entries.map(\.text) == ["first", "third", "second"], "the re-copied entry moved to the top, the other two kept their relative order")
}

@MainActor func test_record_respectsMaxEntriesCap() {
    print("\n[4] History is capped at maxEntries, dropping the oldest")
    let store = ClipboardHistoryStore(fileURL: tempStoreURL(), maxEntries: 3)
    store.record(text: "one")
    store.record(text: "two")
    store.record(text: "three")
    store.record(text: "four")
    expect(store.entries.count == 3, "capped at 3 entries")
    expect(store.entries.map(\.text) == ["four", "three", "two"], "kept the 3 newest, dropped the oldest ('one')")
}

@MainActor func test_history_survivesSimulatedRelaunch() {
    print("\n[5] History survives a simulated relaunch — a fresh store pointed at the same file")
    let sharedFile = tempStoreURL()
    do {
        let store = ClipboardHistoryStore(fileURL: sharedFile)
        store.record(text: "persisted across relaunch")
    }
    let relaunched = ClipboardHistoryStore(fileURL: sharedFile)
    expect(relaunched.entries.count == 1, "entry survived a simulated relaunch")
    expect(relaunched.entries.first?.text == "persisted across relaunch", "and its content came through intact")
}

@MainActor func test_remove_and_clear() {
    print("\n[6] remove() and clear() work correctly")
    let store = ClipboardHistoryStore(fileURL: tempStoreURL())
    store.record(text: "keep")
    store.record(text: "delete me")
    guard let toRemove = store.entries.first(where: { $0.text == "delete me" }) else {
        expect(false, "expected to find the entry to remove")
        return
    }
    store.remove(toRemove.id)
    expect(store.entries.count == 1 && store.entries.first?.text == "keep", "remove() deleted only the targeted entry")

    store.clear()
    expect(store.entries.isEmpty, "clear() emptied the whole history")
}

@MainActor func test_corruptedFile_doesNotSilentlyWipeOnNextSave() {
    print("\n[7] A genuinely corrupted history.json is preserved as a backup, not silently discarded")
    let fileURL = tempStoreURL()
    try? "this is not valid JSON at all".write(to: fileURL, atomically: true, encoding: .utf8)

    let store = ClipboardHistoryStore(fileURL: fileURL)
    expect(store.entries.isEmpty, "starts empty since the file couldn't be decoded")

    let dir = fileURL.deletingLastPathComponent()
    let backups = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?
        .filter { $0.hasPrefix("history.corrupted-") } ?? []
    expect(!backups.isEmpty, "the unreadable original was preserved as a history.corrupted-* backup, not just dropped")

    store.record(text: "new entry after corruption")
    let reloaded = ClipboardHistoryStore(fileURL: fileURL)
    expect(reloaded.entries.count == 1, "the store works normally going forward after recovering from a corrupted file")
}

@MainActor func test_pasteboardMonitor_skipsConcealedAndTransientCopies() async {
    print("\n[8] PasteboardMonitor skips copies marked Concealed or Transient (org.nspasteboard.* convention)")
    let store = ClipboardHistoryStore(fileURL: tempStoreURL())
    let monitor = PasteboardMonitor(pollInterval: 0.05) { text in store.record(text: text) }
    monitor.start()

    let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    let concealedMarker = "MACCLIP_CONCEALED_\(UUID().uuidString)"
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(concealedMarker, forType: .string)
    NSPasteboard.general.setString("1", forType: concealedType)
    try? await Task.sleep(for: .milliseconds(300))
    expect(store.entries.isEmpty, "a copy marked ConcealedType (password managers use this) was never recorded")

    let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    let transientMarker = "MACCLIP_TRANSIENT_\(UUID().uuidString)"
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(transientMarker, forType: .string)
    NSPasteboard.general.setString("1", forType: transientType)
    try? await Task.sleep(for: .milliseconds(300))
    expect(store.entries.isEmpty, "a copy marked TransientType was never recorded either")

    // Sanity: the monitor is still alive and works normally right after —
    // this isn't a case of the monitor having silently broken.
    let normalMarker = "MACCLIP_NORMAL_\(UUID().uuidString)"
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(normalMarker, forType: .string)
    try? await Task.sleep(for: .milliseconds(300))
    expect(store.entries.first?.text == normalMarker, "an ordinary copy right after is still recorded normally")

    monitor.stop()
}

let realClipboardBackup = captureRealClipboard()

await test_pasteboardMonitor_detectsRealCopy()
test_record_dedupsConsecutiveIdenticalCopies()
test_record_movesExistingEntryToTopInsteadOfDuplicating()
test_record_respectsMaxEntriesCap()
test_history_survivesSimulatedRelaunch()
test_remove_and_clear()
test_corruptedFile_doesNotSilentlyWipeOnNextSave()
await test_pasteboardMonitor_skipsConcealedAndTransientCopies()

restoreRealClipboard(realClipboardBackup)

print("\n\(total - failures)/\(total) checks passed.")
exit(failures == 0 ? 0 : 1)
