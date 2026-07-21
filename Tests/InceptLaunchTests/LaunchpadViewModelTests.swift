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

@Test func droppingAppOnAppCreatesFolder() {
    let calendar = makeRecord("Calendar")
    let notes = makeRecord("Notes")
    // Isolate persistence so the test never touches the user's real layout.json.
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: tempURL))
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
        launcher: AppLauncher(workspace: MockWorkspace()),
        layoutPersistence: persistence
    )

    let target = LaunchpadDisplayItem(id: notes.id, title: notes.name, kind: .app(notes))
    viewModel.handleDrop(sourceID: calendar.id, onto: target)

    let page = viewModel.visiblePages.flatMap { $0 }
    #expect(page.count == 1)
    guard case .folder(let folder) = page[0].kind else {
        Issue.record("expected a folder after drop")
        return
    }
    #expect(folder.items.sorted() == [calendar.id, notes.id].sorted())
    #expect(page[0].title == "新文件夹")
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
