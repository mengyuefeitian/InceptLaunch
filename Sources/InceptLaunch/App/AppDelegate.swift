import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = OverlayWindowController()
    private var menuBarController: MenuBarController?
    private var hotKeyManager: GlobalHotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        menuBarController = MenuBarController(overlay: overlay)
        hotKeyManager = GlobalHotKeyManager { [overlay] in overlay.toggle() }
        hotKeyManager?.start()
    }
}
