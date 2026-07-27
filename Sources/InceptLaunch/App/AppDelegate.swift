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
        // Hotkey must open (or toggle) and then re-assert keyboard focus —
        // Carbon hotkeys fire while another app is frontmost.
        hotKeyManager = GlobalHotKeyManager { [overlay] in
            DispatchQueue.main.async {
                overlay.toggle()
            }
        }
        hotKeyManager?.start(keyCode: prefs.hotKeyCode, modifiers: prefs.hotKeyModifiers)
        // Launch straight into the full-screen launchpad overlay.
        overlay.show()
    }

    /// Dock icon click: always open fullscreen launchpad.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        overlay.show()
        return true
    }
}
