import AppKit
import SwiftUI

extension Notification.Name {
    static let inceptLaunchDismiss = Notification.Name("inceptLaunchDismiss")
    static let inceptLaunchPageScroll = Notification.Name("inceptLaunchPageScroll")
    static let inceptLaunchFocusSearch = Notification.Name("inceptLaunchFocusSearch")
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
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private let scrollModel = OverlayScrollModel()
    private let viewModel = LaunchpadViewModel()
    private let preferencesStore = PreferencesStore()

    /// Exposed for the settings window to access hidden apps etc.
    var exposedViewModel: LaunchpadViewModel { viewModel }

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
        // Reset tile tracking so the first click after overlay reopen is never
        // eaten by stale state from the previous session. The new ContentView's
        // PreferenceKey will repopulate tileFrames and set tileFramesReady once
        // the grid has rendered.
        viewModel.tileFramesReady = false
        viewModel.tileFrames = []
        viewModel.openFolder = nil
        viewModel.editMode = false
        viewModel.editDragID = nil
        viewModel.editDragTranslation = .zero
        let prefs = (try? preferencesStore.load()) ?? .default
        Localizer.setLanguage(prefs.language)
        window.contentView = NSHostingView(rootView: ContentView(
            scrollModel: scrollModel,
            viewModel: viewModel,
            preferences: prefs
        ))
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        installScrollMonitor()
        installClickMonitor(window: window)
        installKeyMonitor(window: window)
    }

    func hide() {
        removeScrollMonitor()
        removeClickMonitor()
        removeKeyMonitor()
        window?.orderOut(nil)
        // Return focus to whatever app the user was in before.
        NSApp.hide(nil)
    }

    // MARK: - Scroll Monitor

    private func installScrollMonitor() {
        removeScrollMonitor()
        var lastFlip = Date.distantPast
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
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

    // MARK: - Click Monitor

    private func installClickMonitor(window: NSWindow) {
        removeClickMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            guard let eventWindow = event.window,
                  eventWindow is OverlayWindow else {
                return event
            }

            // If a folder popup is open, let the FolderPopupView handle its own clicks.
            if viewModel.openFolder != nil {
                return event
            }

            // Check if the click is inside the search field.
            var clickedInSearchField = false
            if let fieldEditor = eventWindow.firstResponder as? NSTextView,
               fieldEditor.isFieldEditor,
               let fieldView = fieldEditor.superview {
                let frameInWindow = fieldView.convert(fieldView.bounds, to: nil)
                clickedInSearchField = frameInWindow.contains(event.locationInWindow)
            }

            if clickedInSearchField {
                return event
            }

            // Click is outside the search field.
            // If the search field was focused, defocus it AND handle the
            // dismiss/edit-cancel in this same click (no second click needed).
            if eventWindow.firstResponder is NSTextView {
                eventWindow.makeFirstResponder(nil)
                if viewModel.editMode {
                    viewModel.editMode = false
                } else {
                    self.hide()
                }
                return nil
            }

            // Let SwiftUI handle all other clicks (tiles, background, etc.)
            return event
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Key Monitor

    private func installKeyMonitor(window: NSWindow) {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let chars = event.characters,
                  let first = chars.unicodeScalars.first,
                  first.value >= 32, first.value != 127 else {
                return event
            }
            // Focus search field if not already focused.
            // We post a notification so ContentView can handle it.
            NotificationCenter.default.post(name: .inceptLaunchFocusSearch, object: nil)
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
