import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = OverlayWindowController()
    private var menuBarController: MenuBarController?
    private var hotKeyManager: GlobalHotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Apply the user's chosen app icon to the Dock.
        let prefs = (try? PreferencesStore().load()) ?? .default
        IconSwitcher.apply(prefs.appIconStyle)
        menuBarController = MenuBarController(overlay: overlay)
        hotKeyManager = GlobalHotKeyManager { [overlay] in overlay.toggle() }
        hotKeyManager?.start()
        // Global event monitors require Accessibility permission. Prompt if missing.
        if !GlobalHotKeyManager.hasAccessibility {
            GlobalHotKeyManager.requestAccessibility()
        }
        // Launch straight into the full-screen launchpad overlay.
        overlay.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        overlay.show()
        return true
    }
}
