import AppKit

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let overlay: OverlayWindowController

    init(overlay: OverlayWindowController) {
        self.overlay = overlay
        statusItem.button?.title = "Incept"
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open InceptLaunch", action: #selector(open), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func open() {
        overlay.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
