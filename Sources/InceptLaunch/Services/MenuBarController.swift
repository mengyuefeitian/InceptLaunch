import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let overlay: OverlayWindowController
    private let settings = SettingsWindowController()
    private let statusMenu = NSMenu()

    init(overlay: OverlayWindowController) {
        self.overlay = overlay
        super.init()

        if let symbolImage = NSImage(
            systemSymbolName: "square.grid.3x3.fill",
            accessibilityDescription: "InceptLaunch"
        ) {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            if let rendered = symbolImage.withSymbolConfiguration(config) {
                rendered.isTemplate = true
                statusItem.button?.image = rendered
            }
        }

        let openItem = NSMenuItem(
            title: Localizer.t("menubar.open"),
            action: #selector(open),
            keyEquivalent: ""
        )
        openItem.target = self
        statusMenu.addItem(openItem)

        let settingsItem = NSMenuItem(
            title: Localizer.t("menubar.settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        statusMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: Localizer.t("menubar.quit"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        statusMenu.addItem(quitItem)

        // Important: do NOT set statusItem.menu permanently — that makes left
        // click open the menu instead of the overlay.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            guard let button = statusItem.button else { return }
            // Pop menu under the status item without assigning statusItem.menu
            // (avoids performClick recursion / left-click-opens-menu).
            let origin = NSPoint(x: 0, y: button.bounds.height + 2)
            statusMenu.popUp(positioning: nil, at: origin, in: button)
            return
        }
        overlay.show()
    }

    @objc private func open() {
        overlay.show()
    }

    @objc private func openSettings() {
        settings.show(viewModel: overlay.exposedViewModel)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
