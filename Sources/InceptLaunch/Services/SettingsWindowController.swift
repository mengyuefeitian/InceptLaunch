import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private weak var viewModel: LaunchpadViewModel?
    private var languageObserver: NSObjectProtocol?

    func show(viewModel: LaunchpadViewModel? = nil) {
        self.viewModel = viewModel
        if let window {
            window.title = Localizer.t("settings.title")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Localizer.t("settings.title")
        window.contentView = NSHostingView(rootView: SettingsView(viewModel: viewModel))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        languageObserver = NotificationCenter.default.addObserver(
            forName: .inceptLaunchLanguageChanged, object: nil, queue: .main
        ) { [weak window] _ in
            MainActor.assumeIsolated {
                window?.title = Localizer.t("settings.title")
            }
        }
    }
}
