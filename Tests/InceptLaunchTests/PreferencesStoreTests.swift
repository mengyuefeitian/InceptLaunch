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

@Test func preferencesStoreRoundTripsToDisk() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("preferences.json")
    let store = PreferencesStore(fileStore: JSONFileStore<UserPreferences>(url: url))
    var preferences = UserPreferences.default
    preferences.backgroundBlur = 0.5
    try store.save(preferences)
    #expect(try store.load().backgroundBlur == 0.5)
}
