import AppKit
import SwiftUI

extension Notification.Name {
    static let inceptLaunchDismiss = Notification.Name("inceptLaunchDismiss")
}

struct OverlayState {
    private(set) var isVisible = false

    mutating func toggle() {
        isVisible.toggle()
    }
}

/// Borderless window that can become key so the search field and Esc work.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OverlayWindowController {
    private var window: OverlayWindow?
    private var dismissObserver: NSObjectProtocol?

    init() {
        dismissObserver = NotificationCenter.default.addObserver(
            forName: .inceptLaunchDismiss,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hide()
            }
        }
    }

    func toggle() {
        if let window, window.isVisible {
            hide()
            return
        }
        show()
    }

    func show() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let window = OverlayWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Sit above the menu bar so the overlay covers the whole screen like Launchpad.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.contentView = NSHostingView(rootView: ContentView())
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func hide() {
        window?.orderOut(nil)
        // Return focus to whatever app the user was in before.
        NSApp.hide(nil)
    }
}
