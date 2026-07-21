import AppKit

// Traditional AppKit entry point. We deliberately avoid the SwiftUI `App`
// scene lifecycle: this app is a hotkey/menu-bar driven overlay (like the
// native Launchpad) whose primary window is a manually managed borderless
// NSWindow. The SwiftUI scene system keeps the process hidden when it has no
// scene-managed window, which prevented the overlay from ever appearing.
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
