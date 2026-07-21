import Foundation
import Testing
@testable import InceptLaunch

@MainActor @Test func searchFiltersVisibleItems() {
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

@MainActor @Test func droppingAppOnAppCreatesFolder() {
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

@MainActor @Test func movingAppToTrashTrashesFileAndClearsGrid() async throws {
    let calendar = makeRecord("Calendar")
    let notes = makeRecord("Notes")
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: tempURL))
    let trasher = RecordingTrasher()
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
        layoutPersistence: persistence,
        trasher: trasher
    )

    await viewModel.moveToTrash(calendar.id)

    #expect(trasher.trashedPaths == [calendar.path])
    #expect(viewModel.visiblePages.flatMap { $0 }.map(\.id) == [notes.id])

    // The persisted layout must no longer reference the trashed app.
    let saved = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self,
        from: Data(contentsOf: tempURL)
    )
    let savedAppIDs = saved.pages.flatMap { page in
        page.compactMap { item -> String? in
            if case .app(let id) = item { return id }
            return nil
        }
    }
    #expect(savedAppIDs == [notes.id])

    try? FileManager.default.removeItem(at: tempURL)
}

@MainActor @Test func failedTrashKeepsAppInGrid() async {
    let calendar = makeRecord("Calendar")
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: tempURL))
    let trasher = RecordingTrasher()
    trasher.result = false
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [calendar.id: calendar]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(calendar.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace()),
        layoutPersistence: persistence,
        trasher: trasher
    )

    await viewModel.moveToTrash(calendar.id)

    #expect(viewModel.visiblePages.flatMap { $0 }.map(\.id) == [calendar.id])
    try? FileManager.default.removeItem(at: tempURL)
}

@MainActor @Test func gridRowsFollowScreenHeight() {
    let small = LaunchpadViewModel(screenHeight: 1080)
    let tall = LaunchpadViewModel(screenHeight: 1440)
    #expect(small.gridRows == 4)
    #expect(tall.gridRows == 6)
}

@MainActor @Test func bootstrapRepaginatesLegacyLayoutForScreen() throws {
    // Legacy layout saved before adaptive rows: 45 items on 35-item pages,
    // no recorded page capacity.
    let legacyItems = (0..<45).map { LaunchpadItem.app("app\($0)") }
    let legacy = LaunchpadLayout(
        pages: [Array(legacyItems.prefix(35)), Array(legacyItems.suffix(10))],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    )
    let layoutURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: layoutURL))
    persistence.save(legacy)

    // Scan an empty directory so bootstrap stays fast and deterministic.
    let scanDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-scan-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: scanDir, withIntermediateDirectories: true)
    var preferences = UserPreferences.default
    preferences.scanDirectories = [scanDir.path]
    let preferencesURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-prefs-\(UUID().uuidString).json")
    let preferencesStore = PreferencesStore(fileStore: JSONFileStore<UserPreferences>(url: preferencesURL))
    try preferencesStore.save(preferences)

    let viewModel = LaunchpadViewModel(
        preferencesStore: preferencesStore,
        layoutPersistence: persistence,
        screenHeight: 1080
    )
    viewModel.bootstrapScan()

    let saved = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self,
        from: Data(contentsOf: layoutURL)
    )
    // A 1080p screen paginates at 4 x 7 = 28; the stale apps are pruned but
    // the migrated capacity must be persisted.
    #expect(saved.pageCapacity == 28)
    #expect(saved.pages.allSatisfy { $0.count <= 28 })

    try? FileManager.default.removeItem(at: layoutURL)
    try? FileManager.default.removeItem(at: preferencesURL)
    try? FileManager.default.removeItem(at: scanDir)
}

@MainActor @Test func bootstrapRoutesAppleAppsToAppleFolder() throws {
    let scanDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-scan-\(UUID().uuidString)")
    try makeBundle(in: scanDir, name: "Mail", bundleID: "com.apple.Mail")
    try makeBundle(in: scanDir, name: "Safari", bundleID: "com.apple.Safari")
    try makeBundle(in: scanDir, name: "ThirdParty", bundleID: "com.example.ThirdParty")

    let layoutURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: layoutURL))

    var preferences = UserPreferences.default
    preferences.scanDirectories = [scanDir.path]
    let preferencesURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-prefs-\(UUID().uuidString).json")
    let preferencesStore = PreferencesStore(fileStore: JSONFileStore<UserPreferences>(url: preferencesURL))
    try preferencesStore.save(preferences)

    let viewModel = LaunchpadViewModel(
        preferencesStore: preferencesStore,
        layoutPersistence: persistence,
        screenHeight: 1080
    )
    viewModel.bootstrapScan()

    let saved = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: layoutURL)
    )
    let folder = saved.folders.first(where: { $0.id == "folder:apple" })
    #expect(folder != nil)
    #expect(Set(folder?.items ?? []) == ["bundle:com.apple.Mail", "bundle:com.apple.Safari"])

    // Apple apps must not appear as top-level grid items.
    let topLevelApps = saved.pages.flatMap { $0 }.compactMap { item -> String? in
        if case .app(let id) = item { return id }
        return nil
    }
    #expect(topLevelApps == ["bundle:com.example.ThirdParty"])

    try? FileManager.default.removeItem(at: layoutURL)
    try? FileManager.default.removeItem(at: preferencesURL)
    try? FileManager.default.removeItem(at: scanDir)
}

private final class RecordingTrasher: AppTrashing, @unchecked Sendable {
    var trashedPaths: [String] = []
    var result = true

    func moveToTrash(path: String) async -> Bool {
        trashedPaths.append(path)
        return result
    }
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

/// Writes a minimal `.app` bundle with the given bundle id into `root`.
private func makeBundle(in root: URL, name: String, bundleID: String) throws {
    let contents = root.appendingPathComponent("\(name).app/Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist = contents.appendingPathComponent("Info.plist")
    try """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>\(bundleID)</string>
      <key>CFBundleName</key>
      <string>\(name)</string>
    </dict>
    </plist>
    """.data(using: .utf8)!.write(to: plist)
}
