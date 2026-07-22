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

@Test func appendNewAppsDoesNotDuplicateExistingItems() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 2, rows: 1, iconSize: 72)
    ))
    store.appendNewApps(["a", "b", "c"])
    #expect(store.layout.pages == [[.app("a"), .app("b")], [.app("c")]])
}

@Test func createFolderRemovesAppsFromPagesAndAddsFolder() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a"), .app("b"), .app("c")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    let folder = store.createFolder(
        name: "Work",
        appIDs: ["a", "b"],
        now: Date(timeIntervalSince1970: 1)
    )
    #expect(folder.name == "Work")
    #expect(folder.items == ["a", "b"])
    #expect(store.layout.pages[0] == [.folder(folder.id), .app("c")])
}

@Test func removeAppEverywhereClearsPagesAndFolderMembers() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a"), .app("b")], [.app("c")]],
        folders: [
            LaunchpadFolder(
                id: "folder:1",
                name: "Work",
                items: ["a", "c"],
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        ],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.removeAppEverywhere("a")
    #expect(store.layout.pages == [[.app("b")], [.app("c")]])
    #expect(store.layout.folders[0].items == ["c"])
}

@Test func hideAndUnhideApp() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.hideApp(id: "a")
    #expect(store.layout.hiddenAppIDs.contains("a"))
    #expect(store.layout.pages == [[]])
    store.unhideApp(id: "a")
    #expect(!store.layout.hiddenAppIDs.contains("a"))
}

@Test func resetLayoutCanKeepHiddenApps() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [],
        hiddenAppIDs: ["secret"],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.resetLayout(keepingHiddenApps: true)
    #expect(store.layout.pages == [[]])
    #expect(store.layout.hiddenAppIDs == ["secret"])
}

@Test func addAppToFolderMovesAppOutOfGrid() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a"), .app("b")]],
        folders: [LaunchpadFolder(id: "folder:1", name: "F", items: ["a"], createdAt: Date(), updatedAt: Date())],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.addAppToFolder(appID: "b", folderID: "folder:1")
    #expect(store.layout.folders[0].items == ["a", "b"])
    #expect(store.layout.pages[0] == [.app("a")])
}

@Test func renameFolderUpdatesName() {
    var store = LayoutStore(layout: .init(
        pages: [[.folder("folder:1")]],
        folders: [LaunchpadFolder(id: "folder:1", name: "Old", items: [], createdAt: Date(), updatedAt: Date())],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.renameFolder(id: "folder:1", name: "New")
    #expect(store.layout.folders[0].name == "New")
}

@Test func pruneAppsRemovesStaleItems() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a"), .app("gone"), .folder("folder:1")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.pruneApps(notIn: ["a"])
    #expect(store.layout.pages[0] == [.app("a"), .folder("folder:1")])
}

@Test func syncDirectoryFoldersGroupsMemberApps() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("path:/Applications/Python 3.13/IDLE.app"), .app("other")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    let folder = DirectoryFolder(
        id: "dir:/Applications/Python 3.13",
        name: "Python 3.13",
        path: "/Applications/Python 3.13",
        appIDs: ["path:/Applications/Python 3.13/IDLE.app"]
    )
    store.syncDirectoryFolders([folder])

    // The member app is no longer a top-level grid item; the folder is.
    #expect(store.layout.pages[0].contains(.folder("dir:/Applications/Python 3.13")))
    #expect(!store.layout.pages[0].contains(.app("path:/Applications/Python 3.13/IDLE.app")))
    #expect(store.layout.folders.map(\.id) == ["dir:/Applications/Python 3.13"])
}

@Test func repaginateRechunksLegacyPagesPreservingOrder() {
    // Legacy layout: 45 items across 35-item pages, no recorded capacity.
    let items = (0..<44).map { LaunchpadItem.app("app\($0)") }
    var all = items
    all.insert(.folder("folder:1"), at: 10)
    var store = LayoutStore(layout: .init(
        pages: [Array(all.prefix(35)), Array(all.suffix(10))],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))

    store.repaginate(capacity: 28)

    #expect(store.layout.pages.count == 2)
    #expect(store.layout.pages[0].count == 28)
    #expect(store.layout.pages[1].count == 17)
    #expect(store.layout.pages.flatMap { $0 } == all)
    #expect(store.layout.pageCapacity == 28)
}

@Test func repaginateConsolidatesWhenCapacityGrows() {
    let items = (0..<84).map { LaunchpadItem.app("app\($0)") }
    var store = LayoutStore(layout: .init(
        pages: [Array(items[0..<28]), Array(items[28..<56]), Array(items[56..<84])],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 6, iconSize: 72),
        pageCapacity: 28
    ))

    store.repaginate(capacity: 42)

    #expect(store.layout.pages.map(\.count) == [42, 42])
    #expect(store.layout.pages.flatMap { $0 } == items)
    #expect(store.layout.pageCapacity == 42)
}

@Test func repaginateIsNoOpWhenCapacityMatches() {
    let pages: [[LaunchpadItem]] = [[.app("a"), .app("b")], [.app("c")]]
    var store = LayoutStore(layout: .init(
        pages: pages,
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 4, iconSize: 72),
        pageCapacity: 28
    ))

    store.repaginate(capacity: 28)

    #expect(store.layout.pages == pages)
}

@Test func appendNewAppsUsesRecordedPageCapacity() {
    // Grid config says 7x5, but the recorded capacity (from a 4-row screen)
    // is 28 — new apps must start a new page at 28, not 35.
    var store = LayoutStore(layout: .init(
        pages: [(0..<28).map { LaunchpadItem.app("app\($0)") }],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72),
        pageCapacity: 28
    ))

    store.appendNewApps(["new"])

    #expect(store.layout.pages.count == 2)
    #expect(store.layout.pages[1] == [.app("new")])
}

@Test func syncAppleFolderCreatesFolderForAppleApps() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail", "com.apple.Safari"])

    guard let folder = store.layout.folders.first(where: { $0.id == "folder:apple" }) else {
        Issue.record("expected folder:apple to be created")
        return
    }
    #expect(folder.name == "Apple")
    #expect(folder.items.sorted() == ["com.apple.Mail", "com.apple.Safari"])
    #expect(store.layout.pages.flatMap { $0 }.contains(.folder("folder:apple")))
}

@Test func syncAppleFolderAddsOnlyNewApps() {
    // Mail is on a page (user dragged it out -> settled), Safari is already a
    // member, Notes is brand new (nowhere yet).
    var store = LayoutStore(layout: .init(
        pages: [[.app("com.apple.Mail")]],
        folders: [LaunchpadFolder(
            id: "folder:apple", name: "Apple",
            items: ["com.apple.Safari"], createdAt: Date(), updatedAt: Date()
        )],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail", "com.apple.Safari", "com.apple.Notes"])

    let folder = store.layout.folders.first(where: { $0.id == "folder:apple" })!
    #expect(folder.items.contains("com.apple.Notes"))
    #expect(!folder.items.contains("com.apple.Mail"))
    // Mail stays on the page; it is not yanked back into the folder.
    #expect(store.layout.pages[0].contains(.app("com.apple.Mail")))
}

@Test func syncAppleFolderSkipsWhenFewerThanTwo() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail"])
    #expect(store.layout.folders.isEmpty)
}

@Test func syncAppleFolderKeepsWorkingAfterRename() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [LaunchpadFolder(
            id: "folder:apple", name: "苹果",
            items: ["com.apple.Safari"], createdAt: Date(), updatedAt: Date()
        )],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Safari", "com.apple.Notes"])

    let folder = store.layout.folders.first(where: { $0.id == "folder:apple" })!
    #expect(folder.name == "苹果")
    #expect(folder.items.contains("com.apple.Notes"))
}

@Test func syncAppleFolderExcludesHiddenApps() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [],
        hiddenAppIDs: ["com.apple.Mail"],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    // Mail is hidden; only Safari and Notes are eligible, so the folder is
    // still created (two eligible apps) but must not contain the hidden Mail.
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail", "com.apple.Safari", "com.apple.Notes"])

    guard let folder = store.layout.folders.first(where: { $0.id == "folder:apple" }) else {
        Issue.record("expected folder:apple to be created")
        return
    }
    #expect(!folder.items.contains("com.apple.Mail"))
    #expect(folder.items.sorted() == ["com.apple.Notes", "com.apple.Safari"])
}

@Test func syncAppleFolderCollectsScatteredAppsOnFirstCreation() {
    // Realistic migration: an existing user already has Apple apps scattered
    // across the grid. The first run must gather them into the folder.
    var store = LayoutStore(layout: .init(
        pages: [[.app("com.apple.Mail"), .app("x")], [.app("com.apple.Safari")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail", "com.apple.Safari"])

    guard let folder = store.layout.folders.first(where: { $0.id == "folder:apple" }) else {
        Issue.record("expected folder:apple to be created from scattered apps")
        return
    }
    #expect(folder.items.sorted() == ["com.apple.Mail", "com.apple.Safari"])
    // The scattered Apple apps are removed from the pages; non-Apple "x" stays.
    let pageApps = store.layout.pages.flatMap { $0 }.compactMap { item -> String? in
        if case .app(let id) = item { return id }
        return nil
    }
    #expect(pageApps == ["x"])
    #expect(store.layout.pages.flatMap { $0 }.contains(.folder("folder:apple")))
}

@Test func syncAppleFolderCompactsRemainingAppsIntoDensePages() {
    // Apple apps are scattered across several underfilled pages. After they are
    // gathered into the folder, the remaining apps must flow forward into dense
    // pages so the user is not left flipping through pages full of gaps.
    var store = LayoutStore(layout: .init(
        pages: [
            [.app("com.apple.Mail"), .app("a")],
            [.app("b")],
            [.app("com.apple.Safari"), .app("c")],
        ],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72),
        pageCapacity: 2
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail", "com.apple.Safari"])

    // Apple folder + a, b, c = 4 items at capacity 2 -> exactly 2 dense pages.
    let items = store.layout.pages.flatMap { $0 }
    #expect(items.count == 4)
    #expect(store.layout.pages.count == 2)
    #expect(store.layout.pages.allSatisfy { $0.count == 2 })
    #expect(items.contains(.folder("folder:apple")))
}

@Test func syncAppleFolderDoesNotDuplicateFolderTile() {
    // Regression: an inconsistent state (a folder:apple tile on the grid but no
    // folder definition) must not lead to a second folder:apple tile being
    // inserted on the next consolidation — that left a stray empty slot.
    var store = LayoutStore(layout: .init(
        pages: [[.folder("folder:apple"), .app("a")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail", "com.apple.Safari"])

    let tileCount = store.layout.pages
        .flatMap { $0 }
        .filter { $0 == .folder("folder:apple") }
        .count
    #expect(tileCount == 1)
}
