import SwiftUI

/// A tile's frame together with its identity, so the edit-mode drag can
/// detect overlap with folder tiles and offer "drop into folder".
struct TileFrameInfo: Equatable {
    let id: String
    let frame: CGRect
    let isFolder: Bool
}

/// Preference key that collects the frames of all interactive tile views
/// in the overlay's content-view coordinate space (origin top-left).
struct TileFramePreferenceKey: PreferenceKey {
    static let defaultValue: [TileFrameInfo] = []
    static func reduce(value: inout [TileFrameInfo], nextValue: () -> [TileFrameInfo]) {
        value.append(contentsOf: nextValue())
    }
}
