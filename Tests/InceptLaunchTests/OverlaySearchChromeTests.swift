import AppKit
import Testing
@testable import InceptLaunch

/// Regression: replacing NSTextField's cell with VerticallyCenteredCell must
/// keep the field editable/selectable, otherwise clicks show no caret and
/// keystrokes never insert text.
@MainActor
@Test func searchChromeAllowsTextInputAfterInstall() {
    let chrome = OverlaySearchChrome()
    let parent = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
    chrome.install(on: parent) { _ in }

    #expect(chrome.allowsTextInput)
}

/// Search capsule must host Liquid Glass / material frosted background —
/// not a solid opaque fill (regression when AppKit chrome replaced SwiftUI).
@MainActor
@Test func searchChromeUsesGlassBackgroundAfterInstall() {
    let chrome = OverlaySearchChrome()
    let parent = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
    chrome.install(on: parent) { _ in }

    #expect(chrome.usesGlassBackground)
}
