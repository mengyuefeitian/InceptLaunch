import AppKit
import ApplicationServices

final class GlobalHotKeyManager {
    private let onToggle: () -> Void
    private var monitor: Any?

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [onToggle] event in
            if event.modifierFlags.contains(.option), event.keyCode == 49 {
                onToggle()
            }
        }
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
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
