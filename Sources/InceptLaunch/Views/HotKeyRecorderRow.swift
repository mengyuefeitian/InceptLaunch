import AppKit
import Carbon
import SwiftUI

/// Settings row that displays the current global hotkey and lets the user
/// record a new one. Recording captures exactly one keydown via a local
/// NSEvent monitor, validates it, and — only if `HotKeyManager.updateHotKey`
/// confirms no other app already owns that combo — persists it.
struct HotKeyRecorderRow: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    weak var hotKeyManager: GlobalHotKeyManager?
    let onCommitted: () -> Void

    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var monitor: Any?
    @State private var recordingWindow: NSWindow?
    @State private var windowCloseObserver: NSObjectProtocol?
    @State private var windowResignObserver: NSObjectProtocol?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Localizer.t("settings.hotKey"))
                Spacer()
                Button(buttonTitle) {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .buttonStyle(.bordered)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear { installWindowLifecycleObservers() }
        .onDisappear {
            stopRecording()
            removeWindowLifecycleObservers()
        }
    }

    private var buttonTitle: String {
        if isRecording { return Localizer.t("settings.hotKeyPressKeys") }
        return HotKeyCapture.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    /// Observes the Settings window closing or resigning key so an armed
    /// recorder never survives the window going away — `onDisappear` alone
    /// isn't reliable here because `SettingsWindowController` sets
    /// `isReleasedWhenClosed = false`, so the window object (and this
    /// SwiftUI hierarchy) can persist across a close.
    private func installWindowLifecycleObservers() {
        guard windowCloseObserver == nil, let window = NSApp.keyWindow else { return }
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            Task { @MainActor in stopRecording() }
        }
        windowResignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { _ in
            Task { @MainActor in stopRecording() }
        }
    }

    private func removeWindowLifecycleObservers() {
        if let windowCloseObserver { NotificationCenter.default.removeObserver(windowCloseObserver) }
        if let windowResignObserver { NotificationCenter.default.removeObserver(windowResignObserver) }
        windowCloseObserver = nil
        windowResignObserver = nil
    }

    private func startRecording() {
        errorMessage = nil
        isRecording = true
        // Scope capture to the window that was key when recording began, so
        // a keydown delivered to some other window (e.g. the overlay,
        // invoked via Dock click while armed) is never mistaken for the
        // hotkey the user is configuring here.
        recordingWindow = NSApp.keyWindow
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window == nil || event.window === recordingWindow else {
                // Not meant for the recorder (e.g. the overlay's search
                // field) — let it propagate untouched and stay armed.
                return event
            }
            handleCapturedKey(event)
            return nil // consume — the keystroke configures the hotkey, it doesn't type anywhere
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
        recordingWindow = nil
    }

    private func handleCapturedKey(_ event: NSEvent) {
        let candidateKeyCode = UInt32(event.keyCode)
        let candidateModifiers = HotKeyCapture.carbonModifiers(from: event.modifierFlags)

        guard HotKeyCapture.isValid(keyCode: candidateKeyCode, modifiers: candidateModifiers) else {
            errorMessage = candidateKeyCode == UInt32(kVK_Escape)
                ? Localizer.t("settings.hotKeyEscReserved")
                : Localizer.t("settings.hotKeyNeedsModifier")
            stopRecording()
            return
        }

        guard let hotKeyManager, hotKeyManager.updateHotKey(keyCode: candidateKeyCode, modifiers: candidateModifiers) else {
            errorMessage = Localizer.t("settings.hotKeyConflict")
            stopRecording()
            return
        }

        errorMessage = nil
        keyCode = candidateKeyCode
        modifiers = candidateModifiers
        stopRecording()
        onCommitted()
    }
}
