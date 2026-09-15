import Carbon
import AppKit

/// Registers a single global keyboard shortcut (⌥V by default) that fires
/// even when MacClip isn't the frontmost app.
///
/// Deliberately built on Carbon's `RegisterEventHotKey`, not a
/// `CGEventTap`. A tap that watches every keystroke system-wide requires
/// Accessibility trust (`AXIsProcessTrusted`) before it'll even start;
/// `RegisterEventHotKey` needs no permission at all — it's the same
/// mechanism macOS itself uses for things like "Show Spotlight" (⌘Space),
/// still fully functional today despite Carbon's age, and it's what most
/// hotkey-only (not general keystroke-watching) Mac utilities actually use.
@MainActor
public final class HotKeyManager {
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let onTrigger: () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// - Parameters:
    ///   - keyCode: A virtual keycode (see `Carbon.HIToolbox`'s
    ///     `kVK_*` constants) — 9 is 'V'.
    ///   - modifiers: Carbon modifier flags (`optionKey`, `cmdKey`, …),
    ///     OR'd together — not `NSEvent.ModifierFlags`, a different set of
    ///     raw values Carbon's hotkey API expects.
    public init(keyCode: UInt32 = 9, modifiers: UInt32 = UInt32(optionKey), onTrigger: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.onTrigger = onTrigger
    }

    public func register() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandlerRef)

        // "mclp" as a four-char-code signature — Carbon convention, just
        // needs to be a stable, app-specific tag.
        let signature: OSType = 0x6d636c70
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    /// No `deinit` cleanup here on purpose — Carbon's ref types aren't
    /// `Sendable`, and Swift 6 strict concurrency won't allow touching them
    /// from a class's (always nonisolated) `deinit` even though this class
    /// is `@MainActor`. Callers must call `unregister()` explicitly before
    /// releasing their last reference — `AppModel.stop()` already does.
    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}
