import CoreGraphics

/// Shared layout constants for the Launchpad grid, plus the screen-adaptive
/// row count. Tiles keep their full design size (no visual compression);
/// instead the number of rows per page follows the screen's point height —
/// 4 rows on a 1080p layout, more on taller 4K/5K layouts, like the native
/// Launchpad which fills larger displays with a bigger grid rather than
/// stretching icons.
enum GridMetrics {
    static let columns = 7
    static let tileWidth: CGFloat = 132
    static let tileHeight: CGFloat = 150
    static let iconSize: CGFloat = 104
    static let columnSpacing: CGFloat = 36
    static let rowSpacing: CGFloat = 34

    /// Vertical space taken by everything outside the grid: search field top
    /// padding (60) + field (~38) + stack spacing (32) + dots spacing (18) +
    /// page dots (~25) + bottom margin (40).
    static let chromeHeight: CGFloat = 213

    /// Never drop below this many rows, even on very short screens; the view
    /// shrinks tiles slightly instead as a last resort.
    static let minimumRows = 4

    /// Full-size rows that fit a screen of the given point height.
    /// 1080 → 4 rows, 1440 → 6 rows, 2160 → 10 rows.
    static func rows(forScreenHeight height: CGFloat) -> Int {
        let available = height - chromeHeight
        let fitted = Int(((available + rowSpacing) / (tileHeight + rowSpacing)).rounded(.down))
        return max(minimumRows, fitted)
    }

    static func pageCapacity(rows: Int) -> Int {
        columns * rows
    }
}
