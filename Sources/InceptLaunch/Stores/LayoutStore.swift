import Foundation

struct LayoutStore {
    private(set) var layout: LaunchpadLayout

    init(layout: LaunchpadLayout = .empty) {
        self.layout = layout
    }

    mutating func appendNewApps(_ appIDs: [String]) {
        var existing = Set(layout.pages.flatMap { page in
            page.compactMap { item -> String? in
                if case .app(let id) = item { return id }
                return nil
            }
        }).union(layout.folders.flatMap(\.items))

        let capacity = max(1, layout.grid.columns * layout.grid.rows)
        for appID in appIDs where !existing.contains(appID) && !layout.hiddenAppIDs.contains(appID) {
            if layout.pages.isEmpty { layout.pages = [[]] }
            if layout.pages[layout.pages.count - 1].count >= capacity {
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
            grid: grid
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
}
