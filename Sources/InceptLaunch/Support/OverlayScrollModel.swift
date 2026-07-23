import Foundation

/// Decides whether the overlay's global scroll monitor should hijack
/// mouse-wheel events into horizontal page flips.
///
/// Page-flip hijacking only makes sense on the plain paginated grid. While
/// searching (a tall, vertically scrollable result list), while a folder
/// popup is open (its own scrollable grid), or while the mouse is over an
/// enlarged folder tile (carousel scroll belongs to the tile), scroll events
/// must pass through to the SwiftUI views underneath.
@MainActor
final class OverlayScrollModel {
    private(set) var hijacksScrollWheel = true

    /// When the mouse hovers over an enlarged folder tile, the carousel inside
    /// should receive scroll events instead of the global page-flip handler.
    var isOverEnlargedFolder = false

    func update(isSearching: Bool, isFolderOpen: Bool) {
        hijacksScrollWheel = !isSearching && !isFolderOpen
    }
}
