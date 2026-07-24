import AppKit
import ApplicationServices

final class GlobalHotKeyManager {
    private let onToggle: () -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    func start() {
        // Global monitor: fires when OTHER apps are focused.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [onToggle] event in
            if event.modifierFlags.contains(.option), event.keyCode == 49 {
                onToggle()
            }
        }
        // Local monitor: fires when InceptLaunch itself is the key app
        // (e.g. overlay is showing). Without this the hotkey cannot
        // dismiss the overlay.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [onToggle] event in
            if event.modifierFlags.contains(.option), event.keyCode == 49 {
                onToggle()
                return nil // consume
            }
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    /// Returns true if the app has accessibility permission (required for global monitors).
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility permission. Opens System Settings.
    @MainActor
    static func requestAccessibility() {
        // kAXTrustedCheckOptionPrompt == "AXTrustedCheckOptionPrompt" as CFString
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
