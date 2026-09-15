# DevTools

Hand-rolled pass/fail test harnesses for MacClip — same reasoning as
MacSecureSSH's: no XCTest/Swift Testing available in this environment
(Command Line Tools only, no Xcode), so these are plain `swift run`
executables asserting with a simple `expect()` pattern.

## ClipboardCoreTests

Tests `ClipboardEntry` / `ClipboardHistoryStore` / `PasteboardMonitor`
against the **real** `NSPasteboard.general` — there's no sandboxed
alternative on macOS, and writing to it needs no special permission.
Always saves whatever's really on the clipboard before the run and restores
it afterward, so running these never leaves your actual clipboard changed.

Covers: real-copy detection, consecutive-duplicate dedup, moving a
re-copied older entry back to the top instead of duplicating it, the
`maxEntries` cap, history surviving a simulated relaunch, `remove()`/
`clear()`, a corrupted history.json being preserved as a backup rather than
silently discarded on the next save (the exact bug class that once
destroyed real data in a sibling project — see `ClipboardEntry`'s doc
comment), and respecting the `org.nspasteboard.ConcealedType`/
`TransientType` convention password managers use to mark a copy "don't
record this."

Run:

```
cd DevTools/ClipboardCoreTests && swift run
```

## What can't be verified here

No Accessibility or Screen Recording permission is available in this
development environment, so the actual overlay panel UI, the ⌥V global
hotkey firing, and keyboard navigation inside the popup can't be verified
by clicking/screenshotting the running app the normal way. What *was*
verified for the initial build, using `System Events` UI scripting (which
doesn't need Screen Recording) instead of pixel-based screenshots:

- The app launches, stays running, and registers as a background-only
  (accessory) process — no Dock icon.
- The menu bar extra renders with the exact expected menu items.
- Clicking "Show History" opens a real window of the exact coded size
  (420×360), and toggling again closes it.
- A real copy to the system clipboard shows up in the visible panel.

The hotkey itself (⌥V) could not be triggered via synthetic key events in
this environment (Carbon's `RegisterEventHotKey` didn't respond to
`cliclick`-synthesized key events the way real hardware key presses would)
— worth a real test on an actual keyboard.
