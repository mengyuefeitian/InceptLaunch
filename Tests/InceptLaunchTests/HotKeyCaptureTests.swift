import AppKit
import Carbon
import Testing
@testable import InceptLaunch

@Test func rejectsComboWithNoModifier() {
    #expect(HotKeyCapture.isValid(keyCode: UInt32(kVK_ANSI_K), modifiers: 0) == false)
}

@Test func rejectsBareEscapeEvenWithModifier() {
    #expect(HotKeyCapture.isValid(keyCode: UInt32(kVK_Escape), modifiers: UInt32(optionKey)) == false)
}

@Test func acceptsOptionSpace() {
    #expect(HotKeyCapture.isValid(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) == true)
}

@Test func acceptsCommandShiftK() {
    let modifiers = UInt32(cmdKey) | UInt32(shiftKey)
    #expect(HotKeyCapture.isValid(keyCode: UInt32(kVK_ANSI_K), modifiers: modifiers) == true)
}

@Test func translatesCommandAndOptionModifierFlags() {
    let flags: NSEvent.ModifierFlags = [.command, .option]
    #expect(HotKeyCapture.carbonModifiers(from: flags) == UInt32(cmdKey) | UInt32(optionKey))
}

@Test func translatesNoModifierFlagsToZero() {
    #expect(HotKeyCapture.carbonModifiers(from: []) == 0)
}

@Test func displaysOptionSpace() {
    #expect(HotKeyCapture.displayString(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) == "⌥Space")
}

@Test func displaysCommandShiftReturn() {
    let modifiers = UInt32(cmdKey) | UInt32(shiftKey)
    #expect(HotKeyCapture.displayString(keyCode: UInt32(kVK_Return), modifiers: modifiers) == "⌘⇧Return")
}
