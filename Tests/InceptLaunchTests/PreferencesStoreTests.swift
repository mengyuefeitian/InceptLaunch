import Foundation
import Testing
@testable import InceptLaunch

@Test func defaultPreferencesAreLaunchpadFocused() {
    let preferences = UserPreferences.default
    #expect(preferences.hotKey == "option+space")
    #expect(preferences.showMenuBarIcon == true)
    #expect(preferences.showDockIcon == true)
    #expect(preferences.overlayDisplayMode == .activeDisplay)
}
