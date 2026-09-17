# MacClip — Handoff / Onboarding

A native macOS menu-bar utility: text-only clipboard history, summoned
anywhere with ⌥V. First version (0.1.0), built end-to-end in one session.

## What's built

- **Clipboard capture** (`Packages/ClipboardCore`): polls `NSPasteboard.general`
  (the only mechanism macOS offers — no push API exists), records text
  copies with dedup (consecutive-identical is a no-op; re-copying an older
  entry moves it to the top instead of duplicating), caps history at 1000
  entries, persists to `~/Library/Application Support/MacClip/history.json`.
  Skips anything marked `org.nspasteboard.ConcealedType` or `TransientType`
  — the convention password managers use to mark "don't record this."
- **Global hotkey** (`App/Sources/MacClipCore/HotKeyManager.swift`): ⌥V via
  Carbon's `RegisterEventHotKey` — deliberately not a `CGEventTap`, so no
  Accessibility permission prompt is needed at all.
- **Overlay UI** (`App/Sources/MacClip/`): a borderless, non-activating
  `NSPanel` (doesn't steal focus from whatever app you were in) hosting a
  SwiftUI list — arrow keys to navigate, Enter or click to copy the
  selected entry back to the pasteboard and close, Escape to dismiss
  without selecting, hover to preview-select with the mouse.
- **Menu bar presence**: `MenuBarExtra` with Show History / Clear History /
  Quit — the app is `.accessory` (no Dock icon), so this is the only
  visible, permanent way to know it's running.
- **Build**: `Scripts/build-dmg.sh` — hand-assembled `.app` (no Xcode
  project, Command Line Tools only), ad-hoc signed, DMG with a custom icon.

## What's deliberately NOT built yet

- **Auto-paste**: selecting a history item copies it to the pasteboard;
  you press ⌘V yourself. Simulating a paste keystroke into whatever app
  was frontmost would need synthesizing a `CGEvent`, which — unlike the
  hotkey itself — genuinely does need Accessibility trust. Scoped out of
  this pass on purpose, not an oversight.
- **Search/filter** inside the popup.
- **Images/files** — text only, by explicit request.
- **Developer ID signing + notarization**: ad-hoc signed only right now,
  so any Mac other than the one that built it will hit Gatekeeper's
  "unidentified developer" block on first launch (same situation
  MacSecureSSH is in — see that project's ONBOARDING.md for the exact
  right-click-Open / System Settings workaround, identical here).

## Environment quirks (same as MacSecureSSH)

- Command Line Tools only — no Xcode.app, no `xcodebuild`, no
  XCTest/Swift Testing. All verification is hand-rolled `swift run`
  harnesses under `DevTools/`.
- No Accessibility or Screen Recording permission available to this
  session — couldn't click through or screenshot the running app.
  Verified what could be verified without either: real `NSPasteboard`
  read/write in `DevTools/ClipboardCoreTests`, and real window
  open/close/geometry checks via `System Events` UI scripting (which
  doesn't require Screen Recording) for the app itself. See
  `DevTools/README.md`'s "What can't be verified here" section for the
  exact boundary — the ⌥V hotkey firing specifically could not be
  triggered by synthetic key events in this environment and needs a real
  keyboard press to confirm.

## Repos

- Private source: this repo.
- Public releases-only: a separate repo with just a README and GitHub
  Releases carrying the DMG — same split MacSecureSSH uses, so anyone can
  download and install without seeing the source. See that project's
  handoff notes for exactly how that was set up (`gh repo create`, `gh
  release create`) if a fresh one needs to be made again.

## Suggested next steps, in priority order

1. Confirm ⌥V actually fires on a real keyboard (only unverified piece of
   the whole hotkey→overlay→select chain).
2. Auto-paste via `CGEvent` + Accessibility trust request (with a clear
   in-app explanation of why the permission is needed) — the single
   biggest UX improvement over "copies to pasteboard, paste it yourself."
3. Developer ID signing + notarization once there's a paid Apple Developer
   Program membership to use.
4. Search/filter in the popup once history routinely exceeds a few screens.
