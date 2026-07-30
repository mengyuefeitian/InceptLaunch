import CoreGraphics

/// Shared geometry for folder-create merge hit-testing (preview + drop).
///
/// Live reorder moves the source tile in the layout while the finger still
/// carries the full drag translation. Using `layoutFrame + translation` then
/// double-counts movement (especially Y across rows) and picks the tile
/// *below* the visual ghost. Always center the dragged rect on the pointer.
enum DragMergeGeometry {
    /// Icon-sized rect centered on `pointer`, sized from the source tile frame
    /// when available (falls back to 104×104).
    static func draggedFrame(
        sourceID: String,
        pointer: CGPoint,
        tileFrames: [TileFrameInfo]
    ) -> CGRect {
        let size: CGSize = {
            if let f = tileFrames.first(where: { $0.id == sourceID })?.frame {
                return f.size
            }
            return CGSize(width: 104, height: 104)
        }()
        return CGRect(
            x: pointer.x - size.width / 2,
            y: pointer.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Overlap ratio = intersection area / dragged area.
    static func overlapRatio(dragged: CGRect, target: CGRect) -> CGFloat {
        let overlap = dragged.intersection(target)
        guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return 0 }
        let draggedArea = max(1, dragged.width * dragged.height)
        return (overlap.width * overlap.height) / draggedArea
    }
}
