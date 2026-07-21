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

    static let empty = LaunchpadLayout(
        pages: [[]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    )
}
