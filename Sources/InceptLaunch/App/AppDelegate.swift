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
        // Global event monitors require Accessibility permission.
        if !GlobalHotKeyManager.hasAccessibility {
            GlobalHotKeyManager.requestAccessibility()
            // Show a follow-up alert in case the system prompt was dismissed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showAccessibilityAlertIfNeeded()
            }
        }
        // Launch straight into the full-screen launchpad overlay.
        overlay.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        overlay.show()
        return true
    }

    private func showAccessibilityAlertIfNeeded() {
        guard !GlobalHotKeyManager.hasAccessibility else { return }
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "InceptLaunch 需要辅助功能权限才能使用 ⌥+Space 全局快捷键。\n\n请在系统设置 → 隐私与安全性 → 辅助功能 中，允许 InceptLaunch 控制您的电脑。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
