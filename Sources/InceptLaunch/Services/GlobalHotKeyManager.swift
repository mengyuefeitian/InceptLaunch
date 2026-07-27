import AppKit
import Carbon

/// Registers a system-wide hot key (Option+Space by default) using the
/// Carbon RegisterEventHotKey API, which works globally WITHOUT requiring
/// accessibility permission — unlike NSEvent.addGlobalMonitorForEvents.
final class GlobalHotKeyManager: @unchecked Sendable {
    private let onToggle: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var currentKeyCode: UInt32 = UInt32(kVK_Space)
    private var currentModifiers: UInt32 = UInt32(optionKey)
    private var nextHotKeyID: UInt32 = 1

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    /// Installs the Carbon event handler (once) and registers the initial
    /// hotkey. Call once at launch with the user's stored preference.
    func start(keyCode: UInt32, modifiers: UInt32) {
        installEventHandlerIfNeeded()
        currentKeyCode = keyCode
        currentModifiers = modifiers
        register(keyCode: keyCode, modifiers: modifiers)
    }

    /// Unregisters the current hotkey and registers `keyCode`/`modifiers`.
    /// Returns `false` (and leaves the previous hotkey active) if the new
    /// combo is already registered by another app — the Carbon
    /// `RegisterEventHotKey` error is the only conflict signal available;
    /// there's no API to enumerate who holds a combo.
    @discardableResult
    func updateHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let previousKeyCode = currentKeyCode
        let previousModifiers = currentModifiers
        unregisterCurrent()
        if register(keyCode: keyCode, modifiers: modifiers) {
            currentKeyCode = keyCode
            currentModifiers = modifiers
            return true
        }
        // Roll back so the overlay toggle keeps working.
        _ = register(keyCode: previousKeyCode, modifiers: previousModifiers)
        return false
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                // Hop to main; overlay activation must not race Carbon's own
                // event unwind (that was stealing key focus back).
                DispatchQueue.main.async {
                    manager.onToggle()
                }
                return noErr
            },
            1, &eventType, selfPtr, &eventHandlerRef
        )
    }

    /// Registers `keyCode`/`modifiers` under a fresh hotkey ID. Returns
    /// whether registration succeeded.
    @discardableResult
    private func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        nextHotKeyID += 1
        let hotKeyID = EventHotKeyID(signature: 0x494E4350, id: nextHotKeyID) // "INCP"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    private func unregisterCurrent() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    func stop() {
        unregisterCurrent()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    /// Returns true if the app has accessibility permission.
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility permission. Opens System Settings.
    @MainActor
    static func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandlerRef { RemoveEventHandler(handler) }
    }
}
