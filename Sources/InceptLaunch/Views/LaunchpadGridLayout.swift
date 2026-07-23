import SwiftUI

/// Layout value key that marks a subview as enlarged (spanning 2×2 cells).
private struct EnlargedKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    func layoutEnlarged(_ enlarged: Bool) -> some View {
        layoutValue(key: EnlargedKey.self, value: enlarged)
    }
}

/// A grid layout that arranges tiles in a fixed column count, allowing
/// enlarged items to span 2 columns × 2 rows. Uses a simple occupancy map
/// to flow items around enlarged tiles.
struct LaunchpadGridLayout: Layout {
    var columns: Int = GridMetrics.columns
    var tileWidth: CGFloat = GridMetrics.tileWidth
    var tileHeight: CGFloat = GridMetrics.tileHeight
    var columnSpacing: CGFloat = GridMetrics.columnSpacing
    var rowSpacing: CGFloat = GridMetrics.rowSpacing

    struct Cache {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var totalHeight: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache {
        computeLayout(subviews: subviews)
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = computeLayout(subviews: subviews)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? (CGFloat(columns) * tileWidth + CGFloat(columns - 1) * columnSpacing)
        return CGSize(width: width, height: cache.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        // Center the grid content horizontally within the available width.
        let contentWidth = CGFloat(columns) * tileWidth + CGFloat(columns - 1) * columnSpacing
        let offsetX = max(0, (bounds.width - contentWidth) / 2)

        for (index, subview) in subviews.enumerated() {
            guard index < cache.positions.count else { break }
            let pos = cache.positions[index]
            let size = cache.sizes[index]
            subview.place(
                at: CGPoint(x: bounds.minX + offsetX + pos.x, y: bounds.minY + pos.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
        }
    }

    private func computeLayout(subviews: Subviews) -> Cache {
        var occupied = Set<CellKey>()
        var col = 0
        var row = 0
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []

        let enlargedW = tileWidth * 2 + columnSpacing
        let enlargedH = tileHeight * 2 + rowSpacing

        for subview in subviews {
            let isEnlarged = subview[EnlargedKey.self]

            // Advance to next free cell
            while occupied.contains(CellKey(col: col, row: row)) {
                col += 1
                if col >= columns { col = 0; row += 1 }
            }

            if isEnlarged && col + 1 < columns {
                // Place 2×2 tile
                let x = CGFloat(col) * (tileWidth + columnSpacing)
                let y = CGFloat(row) * (tileHeight + rowSpacing)
                positions.append(CGPoint(x: x, y: y))
                sizes.append(CGSize(width: enlargedW, height: enlargedH))
                occupied.insert(CellKey(col: col, row: row))
                occupied.insert(CellKey(col: col + 1, row: row))
                occupied.insert(CellKey(col: col, row: row + 1))
                occupied.insert(CellKey(col: col + 1, row: row + 1))
                col += 2
            } else {
                // Place 1×1 tile (also fallback if enlarged but at last column)
                let x = CGFloat(col) * (tileWidth + columnSpacing)
                let y = CGFloat(row) * (tileHeight + rowSpacing)
                positions.append(CGPoint(x: x, y: y))
                sizes.append(CGSize(width: tileWidth, height: tileHeight))
                occupied.insert(CellKey(col: col, row: row))
                col += 1
            }

            if col >= columns { col = 0; row += 1 }
        }

        // Compute total height from max row used
        let maxRow = occupied.map(\.row).max() ?? 0
        let totalHeight = CGFloat(maxRow + 1) * tileHeight + CGFloat(maxRow) * rowSpacing

        return Cache(positions: positions, sizes: sizes, totalHeight: totalHeight)
    }
}

private struct CellKey: Hashable {
    let col: Int
    let row: Int
}
