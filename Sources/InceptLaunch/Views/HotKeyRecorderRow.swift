import AppKit
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
        .onDisappear { stopRecording() }
    }

    private var buttonTitle: String {
        if isRecording { return Localizer.t("settings.hotKeyPressKeys") }
        return HotKeyCapture.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    private func startRecording() {
        errorMessage = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
    }

    private func handleCapturedKey(_ event: NSEvent) {
        let candidateKeyCode = UInt32(event.keyCode)
        let candidateModifiers = HotKeyCapture.carbonModifiers(from: event.modifierFlags)

        guard HotKeyCapture.isValid(keyCode: candidateKeyCode, modifiers: candidateModifiers) else {
            errorMessage = candidateModifiers == 0
                ? Localizer.t("settings.hotKeyNeedsModifier")
                : Localizer.t("settings.hotKeyEscReserved")
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
