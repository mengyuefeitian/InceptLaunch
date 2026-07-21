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
