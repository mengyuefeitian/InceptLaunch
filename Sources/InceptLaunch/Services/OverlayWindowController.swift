import AppKit
import SwiftUI

extension Notification.Name {
    static let inceptLaunchDismiss = Notification.Name("inceptLaunchDismiss")
    static let inceptLaunchPageScroll = Notification.Name("inceptLaunchPageScroll")
    static let inceptLaunchFocusSearch = Notification.Name("inceptLaunchFocusSearch")
    /// Posted when edit mode is cancelled from AppKit (click monitor).
    static let inceptLaunchEditModeCancelled = Notification.Name("inceptLaunchEditModeCancelled")
    /// Posted when grid rows/columns settings change so the overlay can re-layout.
    static let inceptLaunchGridSettingsChanged = Notification.Name("inceptLaunchGridSettingsChanged")
    /// Absolute page index (Int) for grid while floating drag flips pages.
    static let inceptLaunchGoToPage = Notification.Name("inceptLaunchGoToPage")
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
    override var acceptsFirstResponder: Bool { true }
}

@MainActor
final class OverlayWindowController {
    private var window: OverlayWindow?
    private var hostingView: NSHostingView<ContentView>?
    private var dismissObserver: NSObjectProtocol?
    private var floatingDragStartObserver: NSObjectProtocol?
    private var focusSearchObserver: NSObjectProtocol?
    private var scrollMonitor: Any?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var floatingDragMonitor: Any?
    private var floatingGhostView: NSView?
    private let searchChrome = OverlaySearchChrome()
    private let scrollModel = OverlayScrollModel()
    private let viewModel = LaunchpadViewModel()
    private let preferencesStore = PreferencesStore()

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
        floatingDragStartObserver = NotificationCenter.default.addObserver(
            forName: .inceptLaunchStartFloatingDrag,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let appID = note.object as? String
            MainActor.assumeIsolated {
                self?.installFloatingDragMonitor(appID: appID)
            }
        }
        focusSearchObserver = NotificationCenter.default.addObserver(
            forName: .inceptLaunchFocusSearch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.searchChrome.focus()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .inceptLaunchClearSearch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.viewModel.searchText = ""
                self?.searchChrome.setText("")
                self?.searchChrome.blur()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .inceptLaunchLanguageChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.searchChrome.refreshPlaceholder()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .inceptLaunchGridSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.viewModel.applyGridSettingsChange()
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
        // If already visible, just re-assert key focus (e.g. hotkey while open).
        if let existing = window, existing.isVisible {
            activateForKeyboard(existing)
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let window = OverlayWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        // Accept keyboard without a titlebar — critical for hotkey-opened sessions.
        window.acceptsMouseMovedEvents = true

        scrollModel.update(isSearching: false, isFolderOpen: false)
        viewModel.tileFramesReady = false
        viewModel.tileFrames = []
        viewModel.openFolder = nil
        viewModel.editMode = false
        viewModel.editDragID = nil
        viewModel.editDragTranslation = .zero
        viewModel.currentPage = 0
        viewModel.searchText = ""
        viewModel.clearFloatingDrag()

        let prefs = (try? preferencesStore.load()) ?? .default
        Localizer.setLanguage(prefs.language)
        viewModel.showSystemApplications = prefs.showSystemApplications
        viewModel.showHiddenInSearch = prefs.showHiddenInSearch
        DiagLog.write("show() loaded prefs: showSystemApps=\(prefs.showSystemApplications) showHidden=\(prefs.showHiddenInSearch)")

        // Root container: hosting view (full) + AppKit search on top.
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let hosting = NSHostingView(rootView: ContentView(
            scrollModel: scrollModel,
            viewModel: viewModel,
            preferences: prefs
        ))
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        self.hostingView = hosting

        searchChrome.install(on: container) { [weak self] text in
            self?.viewModel.searchText = text
        }
        searchChrome.setText("")

        window.contentView = container
        window.setFrame(frame, display: true)
        self.window = window

        installScrollMonitor()
        installClickMonitor(window: window)
        installKeyMonitor(window: window)

        // Hotkey path: Carbon delivers the toggle while another app is frontmost.
        // Must unhide + activate + makeKey or local key monitors never fire and
        // typing never reaches the search field.
        activateForKeyboard(window)
    }

    /// Bring the overlay (and the app) to the front so keyboard events work.
    /// Dock clicks do this implicitly; Carbon hotkeys fire while another app is
    /// frontmost, so we re-assert activation + key status (without mutating
    /// collectionBehavior — incompatible flags crash in _validateCollectionBehavior).
    private func activateForKeyboard(_ window: NSWindow) {
        if NSApp.isHidden {
            NSApp.unhide(nil)
        }
        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        if window.firstResponder == nil || window.firstResponder === window {
            window.makeFirstResponder(window.contentView)
        }
        installKeyMonitor(window: window)

        // Carbon hotkey can bounce focus back; re-assert once on next turn.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window, window.isVisible else { return }
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            window.makeKeyAndOrderFront(nil)
            if !(window.firstResponder is NSTextField || window.firstResponder is NSTextView) {
                window.makeFirstResponder(window.contentView)
            }
        }
    }

    func hide() {
        removeScrollMonitor()
        removeClickMonitor()
        removeKeyMonitor()
        removeFloatingDragMonitor()
        removeFloatingGhost()
        searchChrome.remove()
        hostingView = nil
        window?.orderOut(nil)
        window = nil
        // Hide app so Dock re-click reliably fires applicationShouldHandleReopen.
        NSApp.hide(nil)
    }

    // MARK: - Scroll

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

    // MARK: - Click (jiggle cancel on first blank click)

    private func installClickMonitor(window: NSWindow) {
        removeClickMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            // Local monitors fire on the main thread.
            return self.handleMouseDown(event)
        }
    }

    private func handleMouseDown(_ event: NSEvent) -> NSEvent? {
        guard let eventWindow = event.window, eventWindow is OverlayWindow else {
            return event
        }

        // Floating drag owns the pointer.
        if viewModel.floatingDragApp != nil {
            return event
        }

        // Clicks on the AppKit search field pass through.
        if hitSearchField(event) {
            return event
        }

        // FIRST click while jiggling: cancel and consume.
        if viewModel.editMode {
            viewModel.editMode = false
            NotificationCenter.default.post(name: .inceptLaunchEditModeCancelled, object: nil)
            return nil
        }

        // Folder popup owns its clicks (backdrop closes folder in SwiftUI).
        if viewModel.openFolder != nil {
            return event
        }

        // Searching: blank click (outside the search field) exits fullscreen.
        // Handled here because ScrollView often swallows SwiftUI blank taps.
        // Idle grid: pass the event through so icon taps still launch apps.
        let searching = !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if searching {
            hide()
            return nil
        }

        // Defocus search if it somehow held focus while empty.
        if eventWindow.firstResponder is NSTextView || eventWindow.firstResponder is NSTextField {
            searchChrome.blur()
        }
        return event
    }

    private func hitSearchField(_ event: NSEvent) -> Bool {
        guard let content = window?.contentView else { return false }
        let p = content.convert(event.locationInWindow, from: nil)
        return searchChrome.view.frame.contains(p)
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Floating drag (AppKit ghost — no SwiftUI coordinate flip bugs)

    private func installFloatingDragMonitor(appID: String?) {
        removeFloatingDragMonitor()
        guard let appID, let window else { return }

        // Build AppKit ghost at current mouse position (window coords, bottom-left).
        showFloatingGhost(for: appID, at: window.mouseLocationOutsideOfEventStream)

        floatingDragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            guard let self else { return event }
            return self.handleFloatingDrag(event, appID: appID)
        }
    }

    private func handleFloatingDrag(_ event: NSEvent, appID: String) -> NSEvent? {
        guard let window else { return event }
        let windowPoint = event.locationInWindow

        if event.type == .leftMouseDragged {
            moveFloatingGhost(to: windowPoint)
            // Sync pointer + drive grid live gap / folder-create sensing so
            // drag-out (and edge page-flip handoff) match main-grid feedback.
            let point = swiftUIPoint(fromWindow: windowPoint, in: window)
            self.maybeFlipPageDuringFloatingDrag(windowPoint: windowPoint, window: window)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.viewModel.updateFloatingDrag(at: point)
            }
            return nil
        }

        if event.type == .leftMouseUp {
            let point = swiftUIPoint(fromWindow: windowPoint, in: window)
            viewModel.resolveDrop(
                sourceID: appID,
                at: point,
                page: viewModel.currentPage
            )
            removeFloatingGhost()
            removeFloatingDragMonitor()
            NotificationCenter.default.post(name: .inceptLaunchEditDragEnded, object: nil)
            NotificationCenter.default.post(name: .inceptLaunchGridDragEnded, object: nil)
            return nil
        }
        return event
    }

    private func showFloatingGhost(for appID: String, at windowPoint: NSPoint) {
        removeFloatingGhost()
        guard let window, let content = window.contentView else { return }
        guard let record = viewModel.appRecord(id: appID) else { return }

        let size: CGFloat = 96
        let container = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size + 28))
        container.wantsLayer = true
        container.layer?.zPosition = 10_000

        let icon = NSImageView(frame: NSRect(x: 0, y: 28, width: size, height: size))
        icon.image = NSWorkspace.shared.icon(forFile: record.path)
        icon.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(icon)

        let label = NSTextField(labelWithString: record.name)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: -10, y: 0, width: size + 20, height: 24)
        container.addSubview(label)

        // Always above SwiftUI hosting content and search chrome.
        content.addSubview(container, positioned: .above, relativeTo: nil)
        floatingGhostView = container
        viewModel.floatingDragApp = record
        moveFloatingGhost(to: windowPoint)
    }

    private func moveFloatingGhost(to windowPoint: NSPoint) {
        guard let ghost = floatingGhostView else { return }
        let size = ghost.frame.size
        ghost.frame.origin = NSPoint(
            x: windowPoint.x - size.width / 2,
            y: windowPoint.y - size.height / 2
        )
        // Re-assert topmost in case hosting view re-layered.
        ghost.superview?.addSubview(ghost, positioned: .above, relativeTo: nil)
    }

    private func removeFloatingGhost() {
        floatingGhostView?.removeFromSuperview()
        floatingGhostView = nil
    }

    private func removeFloatingDragMonitor() {
        if let monitor = floatingDragMonitor {
            NSEvent.removeMonitor(monitor)
            floatingDragMonitor = nil
        }
    }

    /// Edge page-flip while AppKit floating drag is active (grid handoff or
    /// folder drag-out). Keeps `viewModel.currentPage` in sync so live gap
    /// targets the page under the pointer.
    private var lastFloatingPageFlip = Date.distantPast
    private func maybeFlipPageDuringFloatingDrag(windowPoint: NSPoint, window: NSWindow) {
        let bounds = window.contentView?.bounds ?? window.frame
        let edgeZone: CGFloat = 56
        let now = Date()
        guard now.timeIntervalSince(lastFloatingPageFlip) > 0.55 else { return }
        let pageCount = max(1, viewModel.visiblePages.count)
        if windowPoint.x < edgeZone, viewModel.currentPage > 0 {
            viewModel.currentPage -= 1
            lastFloatingPageFlip = now
            NotificationCenter.default.post(
                name: .inceptLaunchGoToPage,
                object: viewModel.currentPage
            )
        } else if windowPoint.x > bounds.width - edgeZone,
                  viewModel.currentPage < pageCount - 1 {
            viewModel.currentPage += 1
            lastFloatingPageFlip = now
            NotificationCenter.default.post(
                name: .inceptLaunchGoToPage,
                object: viewModel.currentPage
            )
        }
    }

    /// Window (AppKit, origin bottom-left) → SwiftUI overlay (origin top-left).
    /// Always convert through the `NSHostingView` so the point matches
    /// `TileFramePreferenceKey` / `.named("overlay")` coordinates.
    private func swiftUIPoint(fromWindow windowPoint: NSPoint, in window: NSWindow) -> CGPoint {
        if let hosting = hostingView {
            let p = hosting.convert(windowPoint, from: nil)
            if hosting.isFlipped {
                return CGPoint(x: p.x, y: p.y)
            }
            return CGPoint(x: p.x, y: hosting.bounds.height - p.y)
        }
        guard let content = window.contentView else {
            return CGPoint(x: windowPoint.x, y: windowPoint.y)
        }
        let p = content.convert(windowPoint, from: nil)
        if content.isFlipped {
            return CGPoint(x: p.x, y: p.y)
        }
        return CGPoint(x: p.x, y: content.bounds.height - p.y)
    }

    // MARK: - Key

    private func installKeyMonitor(window: NSWindow) {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Overlay must be up. Do NOT require event.window == OverlayWindow:
            // after a Carbon hotkey, the first keys often arrive with window==nil
            // until the window fully becomes key — those must still start search.
            guard let overlay = self.window, overlay.isVisible else { return event }
            if let ew = event.window, !(ew is OverlayWindow), ew !== overlay {
                return event
            }

            // Esc → leave overlay (works even when NSTextField has focus;
            // SwiftUI onExitCommand does not fire for AppKit first responders).
            if event.keyCode == 53 { // kVK_Escape
                self.handleEscape()
                return nil
            }

            // Already typing in the search field / field editor — pass through
            // so multi-char input and Chinese IME keep working.
            if let fr = overlay.firstResponder ?? event.window?.firstResponder,
               fr is NSTextView || fr is NSTextField {
                return event
            }

            // Printable character → focus search and feed the key (IME-safe).
            guard let chars = event.charactersIgnoringModifiers,
                  let first = chars.unicodeScalars.first,
                  first.value >= 32, first.value != 127,
                  !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.control)
            else {
                return event
            }

            // Ensure we are key, then focus + interpret so the first keystroke
            // is not lost (and Chinese IME still works via interpretKeyEvents).
            overlay.makeKeyAndOrderFront(nil)
            self.searchChrome.interpretKeyEvent(event)
            return nil
        }
    }

    private func handleEscape() {
        if viewModel.editMode {
            viewModel.editMode = false
            NotificationCenter.default.post(name: .inceptLaunchEditModeCancelled, object: nil)
            return
        }
        if viewModel.openFolder != nil {
            viewModel.openFolder = nil
            return
        }
        // Searching or idle → leave fullscreen.
        hide()
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
