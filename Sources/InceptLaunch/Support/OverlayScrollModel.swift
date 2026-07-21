import Foundation

/// Decides whether the overlay's global scroll monitor should hijack
/// mouse-wheel events into horizontal page flips.
///
/// Page-flip hijacking only makes sense on the plain paginated grid. While
/// searching (a tall, vertically scrollable result list) or while a folder
/// popup is open (its own scrollable grid), scroll events must pass through to
/// the SwiftUI `ScrollView` underneath instead of flipping background pages.
@MainActor
final class OverlayScrollModel {
    private(set) var hijacksScrollWheel = true

    func update(isSearching: Bool, isFolderOpen: Bool) {
        hijacksScrollWheel = !isSearching && !isFolderOpen
    }
}
