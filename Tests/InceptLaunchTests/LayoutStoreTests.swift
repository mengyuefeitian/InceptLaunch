import Foundation
import Testing
@testable import InceptLaunch

@Test func layoutRoundTripsThroughJSON() throws {
    let app = AppRecord(
        id: "bundle:com.example.Editor",
        bundleID: "com.example.Editor",
        name: "Editor",
        localizedName: "Editor",
        path: "/Applications/Editor.app",
        iconCacheKey: "bundle:com.example.Editor",
        version: "1.0",
        source: .userApplications,
        isHidden: false,
        isMissing: false,
        lastSeenAt: Date(timeIntervalSince1970: 10),
        lastLaunchedAt: nil
    )
    let layout = LaunchpadLayout(
        pages: [[.app(app.id)]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    )
    let data = try JSONEncoder.inceptLaunch.encode(layout)
    let decoded = try JSONDecoder.inceptLaunch.decode(LaunchpadLayout.self, from: data)
    #expect(decoded == layout)
}
