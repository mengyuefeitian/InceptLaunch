import SwiftUI

/// Preference key that collects the frames of all interactive tile views
/// in the overlay's content-view coordinate space (origin top-left).
/// Used by the dismiss monitor to distinguish tile clicks (pass through)
/// from empty-space clicks (dismiss overlay).
struct TileFramePreferenceKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}
