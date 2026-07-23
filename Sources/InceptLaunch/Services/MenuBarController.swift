import AppKit

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let overlay: OverlayWindowController
    private let settings = SettingsWindowController()

    init(overlay: OverlayWindowController) {
        self.overlay = overlay
        // Use an SF Symbol as the menu bar icon — template image auto-adapts
        // to light/dark mode and matches the app's grid theme.
        if let symbolImage = NSImage(systemSymbolName: "square.grid.3x3.fill",
                                     accessibilityDescription: "InceptLaunch") {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            if let rendered = symbolImage.withSymbolConfiguration(config) {
                rendered.isTemplate = true
                statusItem.button?.image = rendered
            }
        }
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open InceptLaunch", action: #selector(open), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func open() {
        overlay.toggle()
    }

    @objc private func openSettings() {
        settings.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
