import Foundation

struct LayoutStore {
    private(set) var layout: LaunchpadLayout

    init(layout: LaunchpadLayout = .empty) {
        self.layout = layout
    }

    /// Re-chunks all page items into pages of `capacity`, preserving order.
    /// The grid's row count adapts to the screen height (4 rows on 1080p,
    /// more on taller 4K/5K layouts), so the per-page capacity changes with
    /// the display; existing layouts must be repaginated to match.
    /// Enlarged folders consume 4 cells (2×2) instead of 1, so pagination
    /// uses effective cell counts to avoid overflow.
    mutating func repaginate(capacity: Int) {
        guard capacity > 0, layout.effectivePageCapacity != capacity else { return }
        let items = layout.pages.flatMap { $0 }
        var pages: [[LaunchpadItem]] = []
        var current: [LaunchpadItem] = []
        var currentCells = 0
        for item in items {
            let cost = cellCost(item)
            if currentCells > 0 && currentCells + cost > capacity {
                pages.append(current)
                current = []
                currentCells = 0
            }
            current.append(item)
            currentCells += cost
        }
        pages.append(current)
        layout.pages = pages
        layout.pageCapacity = capacity
    }

    mutating func appendNewApps(_ appIDs: [String]) {
        var existing = Set(layout.pages.flatMap { page in
            page.compactMap { item -> String? in
                if case .app(let id) = item { return id }
                return nil
            }
        }).union(layout.folders.flatMap(\.items))

        let capacity = max(1, layout.effectivePageCapacity)
        for appID in appIDs where !existing.contains(appID) && !layout.hiddenAppIDs.contains(appID) {
            if layout.pages.isEmpty { layout.pages = [[]] }
            let lastPage = layout.pages.count - 1
            let currentCells = layout.pages[lastPage].reduce(0) { $0 + cellCost($1) }
            if currentCells >= capacity {
                layout.pages.append([])
            }
            layout.pages[layout.pages.count - 1].append(.app(appID))
            existing.insert(appID)
        }
    }

    /// Upserts directory-backed folders (e.g. /Applications/Python 3.13) into the layout.
    /// Member apps are removed from page grids so they only appear inside the folder,
    /// and the folder itself is placed once if not already present.
    mutating func syncDirectoryFolders(_ folders: [DirectoryFolder], now: Date = Date()) {
        for directoryFolder in folders {
            if let index = layout.folders.firstIndex(where: { $0.id == directoryFolder.id }) {
                layout.folders[index].items = directoryFolder.appIDs
                layout.folders[index].updatedAt = now
            } else {
                layout.folders.append(LaunchpadFolder(
                    id: directoryFolder.id,
                    name: directoryFolder.name,
                    items: directoryFolder.appIDs,
                    createdAt: now,
                    updatedAt: now
                ))
            }
            for appID in directoryFolder.appIDs {
                removeItem(id: "app:\(appID)")
            }
            if !containsFolderItem(directoryFolder.id) {
                if layout.pages.isEmpty { layout.pages = [[]] }
                layout.pages[layout.pages.count - 1].append(.folder(directoryFolder.id))
            }
        }
    }

    /// Stable id of the managed folder that holds Apple's own apps.
    static let appleFolderID = "folder:apple"

    /// Keeps Apple's own apps (bundle id prefix `com.apple.`) together in one
    /// managed folder named "Apple".
    ///
    /// Two phases:
    /// - First sighting (no `folder:apple` yet): collect every Apple app that is
    ///   not hidden and not already inside another folder — including apps already
    ///   placed on grid pages — so an existing user's scattered Apple apps get
    ///   unified into the folder. Requires at least two such apps.
    /// - Afterwards (`folder:apple` exists): additive only. Only brand-new Apple
    ///   apps that appear nowhere yet (not on a page, not in any folder) join, so
    ///   apps a user dragged out of the folder or moved elsewhere stay put. The
    ///   folder is found by its stable id, so a renamed folder still works.
    mutating func syncAppleFolder(appleAppIDs: [String], name: String = "Apple", now: Date = Date()) {
        let onPages = Set(layout.pages.flatMap { page in
            page.compactMap { item -> String? in
                if case .app(let id) = item { return id }
                return nil
            }
        })
        let inFolders = Set(layout.folders.flatMap(\.items))

        if let index = layout.folders.firstIndex(where: { $0.id == Self.appleFolderID }) {
            // Additive only: collect apps that appear nowhere yet.
            let newApps = appleAppIDs.filter {
                !onPages.contains($0) && !inFolders.contains($0) && !layout.hiddenAppIDs.contains($0)
            }
            guard !newApps.isEmpty else { return }
            layout.folders[index].items.append(contentsOf: newApps)
            layout.folders[index].updatedAt = now
            return
        }

        // First sighting: unify all eligible Apple apps, even ones already on
        // the grid, but leave apps the user already grouped in another folder.
        let candidates = appleAppIDs.filter {
            !inFolders.contains($0) && !layout.hiddenAppIDs.contains($0)
        }
        guard candidates.count >= 2 else { return }
        let folder = LaunchpadFolder(
            id: Self.appleFolderID,
            name: name,
            items: candidates,
            createdAt: now,
            updatedAt: now
        )
        for appID in candidates {
            removeItem(id: "app:\(appID)")
        }
        layout.folders.append(folder)
        if layout.pages.isEmpty { layout.pages = [[]] }
        if !containsFolderItem(folder.id) {
            layout.pages[0].insert(.folder(folder.id), at: 0)
        }
        // Removing the Apple apps leaves gaps across the pages; flow the
        // remaining apps forward into dense pages so the grid is not left
        // paginated half-empty.
        compactPages()
    }

    mutating func addAppToFolder(appID: String, folderID: String, now: Date = Date()) {
        guard let index = layout.folders.firstIndex(where: { $0.id == folderID }) else { return }
        guard !layout.folders[index].items.contains(appID) else { return }
        layout.folders[index].items.append(appID)
        layout.folders[index].updatedAt = now
        removeItem(id: "app:\(appID)")
        removeEmptyTrailingPages()
    }

    mutating func renameFolder(id: String, name: String, now: Date = Date()) {
        guard let index = layout.folders.firstIndex(where: { $0.id == id }) else { return }
        layout.folders[index].name = name
        layout.folders[index].updatedAt = now
    }

    /// Removes page items and folder members whose app id is no longer present
    /// in the latest scan, so uninstalled apps don't leave blank cells or dead
    /// references behind.
    mutating func pruneApps(notIn validIDs: Set<String>) {
        for pageIndex in layout.pages.indices {
            layout.pages[pageIndex].removeAll { item in
                if case .app(let id) = item { return !validIDs.contains(id) }
                return false
            }
        }
        for folderIndex in layout.folders.indices {
            layout.folders[folderIndex].items.removeAll { !validIDs.contains($0) }
        }
        removeEmptyTrailingPages()
    }

    mutating func moveItem(id: String, toPage page: Int, index: Int) {
        removeItem(id: id)
        while layout.pages.count <= page {
            layout.pages.append([])
        }
        let boundedIndex = min(max(0, index), layout.pages[page].count)
        layout.pages[page].insert(item(from: id), at: boundedIndex)
        removeEmptyTrailingPages()
    }

    mutating func createFolder(name: String, appIDs: [String], now: Date) -> LaunchpadFolder {
        let folder = LaunchpadFolder(
            id: "folder:\(UUID().uuidString)",
            name: name,
            items: appIDs,
            createdAt: now,
            updatedAt: now
        )
        let firstLocation = firstLocationOfApp(ids: appIDs) ?? (0, 0)
        for appID in appIDs {
            removeItem(id: "app:\(appID)")
        }
        layout.folders.append(folder)
        while layout.pages.count <= firstLocation.page {
            layout.pages.append([])
        }
        let index = min(firstLocation.index, layout.pages[firstLocation.page].count)
        layout.pages[firstLocation.page].insert(.folder(folder.id), at: index)
        removeEmptyTrailingPages()
        return folder
    }

    /// Removes an app from every page and from all folder member lists after
    /// it has been moved to the Trash, so its tile disappears immediately.
    mutating func removeAppEverywhere(_ appID: String) {
        removeItem(id: "app:\(appID)")
        for folderIndex in layout.folders.indices {
            layout.folders[folderIndex].items.removeAll { $0 == appID }
        }
        removeEmptyTrailingPages()
    }

    mutating func hideApp(id: String) {
        layout.hiddenAppIDs.insert(id)
        removeItem(id: "app:\(id)")
    }

    mutating func unhideApp(id: String) {
        layout.hiddenAppIDs.remove(id)
    }

    mutating func resetLayout(keepingHiddenApps: Bool) {
        let hidden = keepingHiddenApps ? layout.hiddenAppIDs : []
        let grid = layout.grid
        layout = LaunchpadLayout(
            pages: [[]],
            folders: [],
            hiddenAppIDs: hidden,
            grid: grid,
            enlargedFolderIDs: []
        )
    }

    private mutating func removeItem(id: String) {
        for pageIndex in layout.pages.indices {
            layout.pages[pageIndex].removeAll { $0.id == id }
        }
    }

    private func containsFolderItem(_ folderID: String) -> Bool {
        layout.pages.contains { page in
            page.contains { item in
                if case .folder(let id) = item { return id == folderID }
                return false
            }
        }
    }

    private func item(from id: String) -> LaunchpadItem {
        id.hasPrefix("folder:") ? .folder(id) : .app(id.replacingOccurrences(of: "app:", with: ""))
    }

    private func firstLocationOfApp(ids: [String]) -> (page: Int, index: Int)? {
        for pageIndex in layout.pages.indices {
            for itemIndex in layout.pages[pageIndex].indices {
                if case .app(let id) = layout.pages[pageIndex][itemIndex], ids.contains(id) {
                    return (pageIndex, itemIndex)
                }
            }
        }
        return nil
    }

    private mutating func removeEmptyTrailingPages() {
        while layout.pages.count > 1 && layout.pages.last?.isEmpty == true {
            layout.pages.removeLast()
        }
    }

    /// Enlarged folders occupy 2×2 = 4 grid cells; everything else is 1 cell.
    private func cellCost(_ item: LaunchpadItem) -> Int {
        if case .folder(let id) = item, layout.enlargedFolderIDs.contains(id) {
            return 4
        }
        return 1
    }

    /// Flattens every page (preserving item order) and re-chunks the items into
    /// dense pages at the current capacity, filling gaps left by removed items
    /// so the grid paginates with the fewest pages.  Enlarged folders consume
    /// 4 cells (2×2) so they are accounted for when splitting pages.
    mutating func compactPages() {
        let capacity = max(1, layout.effectivePageCapacity)
        let items = layout.pages.flatMap { $0 }
        guard !items.isEmpty else {
            layout.pages = [[]]
            return
        }
        var pages: [[LaunchpadItem]] = []
        var current: [LaunchpadItem] = []
        var currentCells = 0
        for item in items {
            let cost = cellCost(item)
            if currentCells > 0 && currentCells + cost > capacity {
                pages.append(current)
                current = []
                currentCells = 0
            }
            current.append(item)
            currentCells += cost
        }
        pages.append(current)
        layout.pages = pages
    }

    /// Marks a folder as enlarged (displayed as a 2×2 tile with 3×3 internal grid).
    mutating func enlargeFolder(id: String) {
        layout.enlargedFolderIDs.insert(id)
    }

    /// Reverts a folder back to its normal 1×1 tile size.
    mutating func shrinkFolder(id: String) {
        layout.enlargedFolderIDs.remove(id)
    }

    /// Whether a folder is currently in enlarged mode.
    func isEnlarged(_ id: String) -> Bool {
        layout.enlargedFolderIDs.contains(id)
    }
}
