import AppKit

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

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
