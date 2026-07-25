import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let overlay: OverlayWindowController
    private let settings = SettingsWindowController()
    private let statusMenu = NSMenu()
    private var languageObserver: NSObjectProtocol?

    private var settingsItem: NSMenuItem!
    private var logsItem: NSMenuItem!
    private var quitItem: NSMenuItem!

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

        settingsItem = NSMenuItem(title: "", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        logsItem = NSMenuItem(title: "", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        statusMenu.addItem(logsItem)

        statusMenu.addItem(NSMenuItem.separator())

        quitItem = NSMenuItem(title: "", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)

        refreshMenuTitles()

        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        languageObserver = NotificationCenter.default.addObserver(
            forName: .inceptLaunchLanguageChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshMenuTitles()
            }
        }
    }

    private func refreshMenuTitles() {
        settingsItem.title = Localizer.t("menubar.settings")
        logsItem.title = Localizer.t("menubar.logs")
        quitItem.title = Localizer.t("menubar.quit")
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            guard let button = statusItem.button else { return }
            let origin = NSPoint(x: 0, y: button.bounds.height + 2)
            statusMenu.popUp(positioning: nil, at: origin, in: button)
            return
        }
        overlay.show()
    }

    @objc private func openSettings() {
        settings.show(viewModel: overlay.exposedViewModel)
    }

    @objc private func openLogs() {
        guard let logURL = DiagLog.logFileURL else { return }
        if !FileManager.default.fileExists(atPath: logURL.path) {
            DiagLog.write("log file created")
        }
        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
