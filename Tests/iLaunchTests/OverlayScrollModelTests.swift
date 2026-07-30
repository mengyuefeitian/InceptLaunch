import Testing
@testable import iLaunch

/// The overlay turns mouse-wheel scrolling into horizontal page flips — but
/// only on the plain paginated grid. While searching (a tall, vertically
/// scrollable result list) or while a folder popup is open (its own scrollable
/// grid), scrolling must reach the SwiftUI ScrollView instead of flipping the
/// background pages.
@MainActor
@Suite struct OverlayScrollModelTests {
    @Test func hijacksByDefaultOnPlainGrid() {
        let model = OverlayScrollModel()
        #expect(model.hijacksScrollWheel)
    }

    @Test func stopsHijackingWhileSearching() {
        let model = OverlayScrollModel()
        model.update(isSearching: true, isFolderOpen: false)
        #expect(!model.hijacksScrollWheel)
    }

    @Test func stopsHijackingWhileFolderOpen() {
        let model = OverlayScrollModel()
        model.update(isSearching: false, isFolderOpen: true)
        #expect(!model.hijacksScrollWheel)
    }

    @Test func resumesHijackingWhenSearchClearedAndFolderClosed() {
        let model = OverlayScrollModel()
        model.update(isSearching: true, isFolderOpen: false)
        model.update(isSearching: false, isFolderOpen: false)
        #expect(model.hijacksScrollWheel)
    }

    @Test func staysPassiveWhenSearchingWithFolderOpen() {
        let model = OverlayScrollModel()
        model.update(isSearching: true, isFolderOpen: true)
        #expect(!model.hijacksScrollWheel)
    }
}
