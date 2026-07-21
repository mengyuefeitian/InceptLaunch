import Foundation

struct LaunchpadLayout: Codable, Equatable {
    struct Grid: Codable, Equatable {
        var columns: Int
        var rows: Int
        var iconSize: Double
    }

    var pages: [[LaunchpadItem]]
    var folders: [LaunchpadFolder]
    var hiddenAppIDs: Set<String>
    var grid: Grid
    /// Items per page, recorded from the screen-adaptive grid the last time
    /// the layout was saved. nil in legacy files, which paginated at a fixed
    /// columns x rows (7 x 5 = 35).
    var pageCapacity: Int?

    var effectivePageCapacity: Int {
        pageCapacity ?? max(1, grid.columns * grid.rows)
    }

    static let empty = LaunchpadLayout(
        pages: [[]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72),
        pageCapacity: nil
    )
}
