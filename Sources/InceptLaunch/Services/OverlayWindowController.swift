import AppKit
import SwiftUI

extension Notification.Name {
    static let inceptLaunchDismiss = Notification.Name("inceptLaunchDismiss")
    static let inceptLaunchPageScroll = Notification.Name("inceptLaunchPageScroll")
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
    private var scrollMonitor: Any?
    private let scrollModel = OverlayScrollModel()

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
        scrollModel.update(isSearching: false, isFolderOpen: false)
        window.contentView = NSHostingView(rootView: ContentView(scrollModel: scrollModel))
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        installScrollMonitor()
    }

    func hide() {
        removeScrollMonitor()
        window?.orderOut(nil)
        // Return focus to whatever app the user was in before.
        NSApp.hide(nil)
    }

    /// Turn mouse-wheel / trackpad scrolling into page flips while the overlay
    /// is up. A continuous scroll gesture flips at most one page per interval.
    private func installScrollMonitor() {
        removeScrollMonitor()
        var lastFlip = Date.distantPast
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            // While searching or with a folder popup open, scrolling belongs to
            // the SwiftUI ScrollView underneath — let it through untouched.
            let hijacks = MainActor.assumeIsolated { self?.scrollModel.hijacksScrollWheel ?? false }
            guard hijacks else { return event }
            let now = Date()
            guard now.timeIntervalSince(lastFlip) > 0.3 else { return nil }
            let deltaY = event.scrollingDeltaY
            let deltaX = event.scrollingDeltaX
            let delta = abs(deltaY) >= abs(deltaX) ? deltaY : deltaX
            guard abs(delta) > 0.5 else { return nil }
            let direction = delta < 0 ? 1 : -1
            NotificationCenter.default.post(name: .inceptLaunchPageScroll, object: direction)
            lastFlip = now
            return nil
        }
    }

    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }
}
