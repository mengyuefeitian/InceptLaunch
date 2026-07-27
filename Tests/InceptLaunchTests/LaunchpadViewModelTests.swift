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

@MainActor @Test func gridRowsFollowScreenHeight() throws {
    // Rows are now fixed by user preference (default 4), not screen-adaptive.
    let prefsURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-prefs-\(UUID().uuidString).json")
    let store = PreferencesStore(fileStore: JSONFileStore<UserPreferences>(url: prefsURL))
    try store.save(.default)

    let small = LaunchpadViewModel(preferencesStore: store, screenHeight: 1080)
    let tall = LaunchpadViewModel(preferencesStore: store, screenHeight: 1440)
    #expect(small.gridRows == 4)
    #expect(tall.gridRows == 4)

    try? FileManager.default.removeItem(at: prefsURL)
}

@MainActor @Test func bootstrapRepaginatesLegacyLayoutForScreen() async throws {
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
    await viewModel.bootstrapScan()

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

@MainActor @Test func bootstrapRoutesAppleAppsToAppleFolder() async throws {
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
    await viewModel.bootstrapScan()

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

@MainActor @Test func bootstrapKeepsLoneAppleAppOnGrid() async throws {
    let scanDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-scan-\(UUID().uuidString)")
    // Only one Apple app: below the folder threshold, so it must stay on the grid.
    try makeBundle(in: scanDir, name: "Mail", bundleID: "com.apple.Mail")
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
    await viewModel.bootstrapScan()

    let saved = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: layoutURL)
    )
    // No Apple folder for a single Apple app.
    #expect(saved.folders.first(where: { $0.id == "folder:apple" }) == nil)
    // Both apps appear as top-level grid items.
    let topLevelApps = Set(saved.pages.flatMap { $0 }.compactMap { item -> String? in
        if case .app(let id) = item { return id }
        return nil
    })
    #expect(topLevelApps == ["bundle:com.apple.Mail", "bundle:com.example.ThirdParty"])

    try? FileManager.default.removeItem(at: layoutURL)
    try? FileManager.default.removeItem(at: preferencesURL)
    try? FileManager.default.removeItem(at: scanDir)
}

/// Regression test: `bootstrapScan()` used to call `AppScanner.scanAll`
/// synchronously on the MainActor, which froze the overlay (unresponsive to
/// Esc/click, blank render) for the full duration of the filesystem +
/// Spotlight scan. The scan must run off the main thread.
@MainActor @Test func bootstrapScanRunsScannerOffMainThread() async throws {
    let scanDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-scan-\(UUID().uuidString)")
    try makeBundle(in: scanDir, name: "TestApp", bundleID: "com.example.TestApp")

    let layoutURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: layoutURL))

    var preferences = UserPreferences.default
    preferences.scanDirectories = [scanDir.path]
    let preferencesURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-prefs-\(UUID().uuidString).json")
    let preferencesStore = PreferencesStore(fileStore: JSONFileStore<UserPreferences>(url: preferencesURL))
    try preferencesStore.save(preferences)

    let sawBackgroundThread = ThreadObservationBox()
    var scanner = AppScanner()
    scanner.finderNameProvider = { _ in
        if !Thread.isMainThread {
            sawBackgroundThread.markSeen()
        }
        return nil
    }

    let viewModel = LaunchpadViewModel(
        scanner: scanner,
        preferencesStore: preferencesStore,
        layoutPersistence: persistence,
        screenHeight: 1080
    )
    await viewModel.bootstrapScan()

    #expect(sawBackgroundThread.seen)

    try? FileManager.default.removeItem(at: layoutURL)
    try? FileManager.default.removeItem(at: preferencesURL)
    try? FileManager.default.removeItem(at: scanDir)
}

@MainActor @Test func bootstrapRescanKeepsDraggedOutAppleAppOnGrid() async throws {
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

    // First scan: the two Apple apps are collected into folder:apple.
    await viewModel.bootstrapScan()

    // Simulate the user dragging Mail out of the folder onto the grid, then
    // persisting that change (as the app does after a drag).
    let mailID = "bundle:com.apple.Mail"
    var saved = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: layoutURL)
    )
    if let idx = saved.folders.firstIndex(where: { $0.id == "folder:apple" }) {
        saved.folders[idx].items.removeAll { $0 == mailID }
    }
    saved.pages[0].append(.app(mailID))
    try JSONEncoder.inceptLaunch.encode(saved).write(to: layoutURL)

    // Second scan: must NOT yank Mail back into the folder or duplicate it.
    await viewModel.bootstrapScan()

    let final = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: layoutURL)
    )
    // Core guarantee: Mail was not yanked back into a folder / duplicated.
    // After drag-out left a single member, bootstrap may dissolve the folder
    // (≤1 member policy) — either way Mail must stay on the grid once.
    let folder = final.folders.first(where: { $0.id == "folder:apple" })
    if let folder {
        #expect(!folder.items.contains(mailID))
    }
    let gridApps = final.pages.flatMap { $0 }.compactMap { item -> String? in
        if case .app(let id) = item { return id }
        return nil
    }
    #expect(gridApps.filter { $0 == mailID }.count == 1)
    #expect(gridApps.contains("bundle:com.example.ThirdParty"))

    try? FileManager.default.removeItem(at: layoutURL)
    try? FileManager.default.removeItem(at: preferencesURL)
    try? FileManager.default.removeItem(at: scanDir)
}

@MainActor @Test func systemAppsHiddenWhenToggleOff() {
    let systemApp = AppRecord(
        id: "bundle:com.apple.Safari",
        bundleID: "com.apple.Safari",
        name: "Safari",
        localizedName: "Safari",
        path: "/System/Applications/Safari.app",
        iconCacheKey: "safari",
        version: nil,
        source: .systemApplications,
        isHidden: false,
        isMissing: false,
        lastSeenAt: Date(timeIntervalSince1970: 1),
        lastLaunchedAt: nil
    )
    let userApp = makeRecord("Editor")
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            systemApp.id: systemApp,
            userApp.id: userApp
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(systemApp.id), .app(userApp.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.showSystemApplications = false
    let visible = viewModel.visiblePages.flatMap { $0 }
    #expect(visible.map(\.id) == [userApp.id])

    viewModel.showSystemApplications = true
    let visibleAgain = viewModel.visiblePages.flatMap { $0 }
    #expect(visibleAgain.map(\.id) == [systemApp.id, userApp.id])
}

@MainActor @Test func searchIncludesHiddenAppsWhenEnabled() {
    let hiddenApp = AppRecord(
        id: "bundle:com.example.Secret",
        bundleID: "com.example.Secret",
        name: "Secret",
        localizedName: "Secret",
        path: "/Applications/Secret.app",
        iconCacheKey: "secret",
        version: nil,
        source: .localApplications,
        isHidden: true,
        isMissing: false,
        lastSeenAt: Date(timeIntervalSince1970: 1),
        lastLaunchedAt: nil
    )
    let normalApp = makeRecord("Notes")
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            hiddenApp.id: hiddenApp,
            normalApp.id: normalApp
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(normalApp.id)]],
            folders: [],
            hiddenAppIDs: [hiddenApp.id],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.showHiddenInSearch = true
    viewModel.searchText = "sec"
    let results = viewModel.visiblePages.flatMap { $0 }
    #expect(results.map(\.id) == [hiddenApp.id])
    #expect(results[0].isHiddenApp == true)

    viewModel.showHiddenInSearch = false
    let resultsHidden = viewModel.visiblePages.flatMap { $0 }
    #expect(resultsHidden.isEmpty)
}

@MainActor @Test func reorderInFolderUpdatesLayoutAndPersists() throws {
    let appA = makeRecord("Alpha")
    let appB = makeRecord("Beta")
    let appC = makeRecord("Gamma")
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: tempURL))
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            appA.id: appA, appB.id: appB, appC.id: appC
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.folder("folder:test")]],
            folders: [LaunchpadFolder(
                id: "folder:test",
                name: "Test",
                items: [appA.id, appB.id, appC.id],
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 1)
            )],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace()),
        layoutPersistence: persistence
    )

    viewModel.reorderInFolder(folderID: "folder:test", appID: appC.id, toIndex: 0)

    let saved = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: tempURL)
    )
    #expect(saved.folders[0].items == [appC.id, appA.id, appB.id])
    try? FileManager.default.removeItem(at: tempURL)
}

@MainActor @Test func liveReorderMovesItemWithoutPersisting() {
    let appA = makeRecord("Alpha")
    let appB = makeRecord("Beta")
    let appC = makeRecord("Gamma")
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: tempURL))
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            appA.id: appA, appB.id: appB, appC.id: appC
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(appA.id), .app(appB.id), .app(appC.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace()),
        layoutPersistence: persistence
    )

    viewModel.liveReorder(draggedID: appC.id, toIndex: 0, page: 0)

    let visible = viewModel.visiblePages[0]
    #expect(visible.map(\.id) == [appC.id, appA.id, appB.id])

    // liveReorder must NOT persist (only final drop persists).
    let saved = try? JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: tempURL)
    )
    #expect(saved == nil || saved?.pages[0] != [.app(appC.id), .app(appA.id), .app(appB.id)])
    try? FileManager.default.removeItem(at: tempURL)
}

@MainActor @Test func liveReorderInFolderMovesMember() {
    let appA = makeRecord("Alpha")
    let appB = makeRecord("Beta")
    let appC = makeRecord("Gamma")
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            appA.id: appA, appB.id: appB, appC.id: appC
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.folder("folder:test")]],
            folders: [LaunchpadFolder(
                id: "folder:test",
                name: "Test",
                items: [appA.id, appB.id, appC.id],
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 1)
            )],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.liveReorderInFolder(folderID: "folder:test", appID: appC.id, toIndex: 0)

    let folder = viewModel.visiblePages[0].first(where: { $0.id == "folder:test" })
    #expect(folder?.members.map(\.id) == [appC.id, appA.id, appB.id])
}

@MainActor @Test func cancelLiveReorderRestoresOriginalOrder() {
    let appA = makeRecord("Alpha")
    let appB = makeRecord("Beta")
    let appC = makeRecord("Gamma")
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            appA.id: appA, appB.id: appB, appC.id: appC
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(appA.id), .app(appB.id), .app(appC.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.beginLiveReorder(draggedID: appC.id, page: 0)
    viewModel.liveReorder(draggedID: appC.id, toIndex: 0, page: 0)
    #expect(viewModel.visiblePages[0].map(\.id) == [appC.id, appA.id, appB.id])

    viewModel.cancelLiveReorder(page: 0)
    #expect(viewModel.visiblePages[0].map(\.id) == [appA.id, appB.id, appC.id])
}

/// Floating drag-out must park the app on the grid so live gap animation works.
@MainActor @Test func updateFloatingDragInsertsAppOntoGrid() {
    let appA = makeRecord("Alpha")
    let appB = makeRecord("Beta")
    let appC = makeRecord("Gamma")
    // Keep 2+ members so extract does not dissolve the folder.
    let folder = LaunchpadFolder(
        id: "folder:test",
        name: "Test",
        items: [appB.id, appC.id],
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1)
    )
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            appA.id: appA, appB.id: appB, appC.id: appC
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(appA.id), .folder("folder:test")]],
            folders: [folder],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.beginFloatingDragOut(appID: appC.id, at: CGPoint(x: 100, y: 100))
    #expect(viewModel.floatingDragApp?.id == appC.id)
    // Extracted: not yet on grid
    #expect(!viewModel.visiblePages[0].contains(where: { $0.id == appC.id }))

    viewModel.tileFrames = [
        TileFrameInfo(id: appA.id, frame: CGRect(x: 0, y: 0, width: 100, height: 140), isFolder: false)
    ]
    viewModel.updateFloatingDrag(at: CGPoint(x: 200, y: 50))

    #expect(viewModel.visiblePages[0].contains(where: { $0.id == appC.id }))
    #expect(viewModel.editDragID == appC.id)
}

/// Live reorder during drag may temporarily overflow a page (extra visual row).
/// Finalizing the drag must push overflow forward so the page fits capacity.
@MainActor @Test func endLiveReorderEnforcesPageCapacityAfterCrossPageMove() {
    // 4×7 = 28 capacity. Fill page 0; live-reorder an extra app onto it.
    let records = (0..<29).map { makeRecord("App\($0)") }
    let page0 = Array(records.prefix(28).map { LaunchpadItem.app($0.id) })
    let page1 = [LaunchpadItem.app(records[28].id)]
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })),
        layoutStore: LayoutStore(layout: .init(
            pages: [page0, page1],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 4, iconSize: 72),
            pageCapacity: 28
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    let dragged = records[28].id
    viewModel.beginLiveReorder(draggedID: dragged, page: 1)
    // Mid-drag: park on page 0 (allowed temporary overflow for preview).
    viewModel.liveReorder(draggedID: dragged, toIndex: 28, page: 0)
    #expect(viewModel.visiblePages[0].count == 29)

    viewModel.endLiveReorder()

    #expect(viewModel.visiblePages[0].count <= 28)
    let allIDs = viewModel.visiblePages.flatMap { $0.map(\.id) }
    #expect(allIDs.contains(dragged))
    #expect(allIDs.count == 29)
    // Every page must fit 4×7 cell capacity after finalize.
    for page in viewModel.visiblePages {
        #expect(page.count <= 28)
    }
}

private final class ThreadObservationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _seen = false

    var seen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _seen
    }

    func markSeen() {
        lock.lock()
        _seen = true
        lock.unlock()
    }
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
