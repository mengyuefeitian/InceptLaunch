import Foundation
import Testing
@testable import InceptLaunch

@Test func searchFiltersVisibleItems() {
    let calendar = makeRecord("Calendar")
    let notes = makeRecord("Notes")
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            calendar.id: calendar,
            notes.id: notes
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(calendar.id), .app(notes.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.searchText = "cal"

    #expect(viewModel.visiblePages.flatMap { $0 }.map(\.title) == ["Calendar"])
}

private func makeRecord(_ name: String) -> AppRecord {
    AppRecord(
        id: "bundle:com.example.\(name)",
        bundleID: "com.example.\(name)",
        name: name,
        localizedName: name,
        path: "/Applications/\(name).app",
        iconCacheKey: name,
        version: nil,
        source: .localApplications,
        isHidden: false,
        isMissing: false,
        lastSeenAt: Date(timeIntervalSince1970: 1),
        lastLaunchedAt: nil
    )
}
