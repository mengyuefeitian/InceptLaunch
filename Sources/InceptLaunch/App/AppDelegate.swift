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
        // If accessibility permission is missing, the system will show its own prompt
        // via AXIsProcessTrustedWithOptions. Don't show our own modal alert — it
        // would appear on top of the overlay and block all interactions.
        // Launch straight into the full-screen launchpad overlay.
        overlay.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        overlay.show()
        return true
    }
}
