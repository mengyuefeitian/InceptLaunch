import AppKit
import Foundation
import Observation

struct LaunchpadDisplayItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case app(AppRecord)
        case folder(LaunchpadFolder)
    }

    var id: String
    var title: String
    var kind: Kind
    var members: [AppRecord] = []
    var isHiddenApp: Bool = false
}

@MainActor
@Observable
final class LaunchpadViewModel {
    var searchText = ""
    var selectedItemID: String?

    /// When true, tiles jiggle and can be dragged to reorder.
    var editMode = false

    /// The ID of the tile currently being dragged in edit mode (nil if not dragging).
    var editDragID: String?

    /// Translation of the current edit-mode drag.
    var editDragTranslation: CGSize = .zero

    /// Frames of all interactive tile views in the overlay's content-view
    /// coordinate space (origin top-left). Updated via PreferenceKey from
    /// LaunchpadGridView. Includes tile identity so the edit-mode drag can
    /// detect overlap with folder tiles.
    var tileFrames: [TileFrameInfo] = []

    /// True once the PreferenceKey has reported at least one batch of tile
    /// frames. Before this, dismiss monitors default to "allow" (pass the
    /// click through) so the first click after overlay-open is never eaten
    /// by a premature empty-space dismiss.
    var tileFramesReady = false

    /// The currently-open folder popup, if any. Lives on the @Observable
    /// model (not @State in ContentView) so the NSEvent click monitor
    /// closure can read it by reference — @State in a struct is invisible
    /// inside captured closures.
    var openFolder: LaunchpadDisplayItem?

    /// The page currently displayed in the grid. Updated by LaunchpadGridView
    /// so drag-out from a folder can insert on the page the user is viewing.
    var currentPage = 0

    var showSystemApplications: Bool = true
    var showHiddenInSearch: Bool = true

    /// App extracted from a folder mid-drag — follows the pointer as a floating
    /// ghost until drop resolves insert / merge.
    var floatingDragApp: AppRecord?

    /// Absolute pointer position in the overlay coordinate space for the ghost.
    var floatingDragPoint: CGPoint = .zero

    /// The item currently being live-reorder-dragged on the main grid (for overlay rendering).
    var gridDragItem: LaunchpadDisplayItem?

    /// Absolute pointer position in overlay coordinate space during grid drag.
    var gridDragLocation: CGPoint = .zero

    private var appIndex: AppIndexStore
    private var layoutStore: LayoutStore
    private let matcher: SearchMatcher
    private let launcher: AppLauncher
    private let scanner: AppScanner
    private let preferencesStore: PreferencesStore
    private let layoutPersistence: LayoutPersistenceStore
    private let trasher: AppTrashing
    private let screenHeight: CGFloat

    /// Rows per page for the current display: full-size tiles, never
    /// compressed — 1080p gets 4 rows, taller 4K/5K layouts get more.
    var gridRows: Int {
        GridMetrics.rows(forScreenHeight: screenHeight)
    }

    init(
        appIndex: AppIndexStore = AppIndexStore(),
        layoutStore: LayoutStore = LayoutStore(),
        matcher: SearchMatcher = SearchMatcher(),
        launcher: AppLauncher = AppLauncher(),
        scanner: AppScanner = AppScanner(),
        preferencesStore: PreferencesStore = PreferencesStore(),
        layoutPersistence: LayoutPersistenceStore = LayoutPersistenceStore(),
        trasher: AppTrashing = SystemAppTrasher(),
        screenHeight: CGFloat = NSScreen.main?.frame.height ?? 1080
    ) {
        self.appIndex = appIndex
        self.layoutStore = layoutStore
        self.matcher = matcher
        self.launcher = launcher
        self.scanner = scanner
        self.preferencesStore = preferencesStore
        self.layoutPersistence = layoutPersistence
        self.trasher = trasher
        self.screenHeight = screenHeight
    }

    var visiblePages: [[LaunchpadDisplayItem]] {
        let recordsByID = appIndex.records

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let hiddenIDs = layoutStore.layout.hiddenAppIDs
            return [matcher.ranked(query: searchText, records: Array(recordsByID.values))
                .filter { record in
                    if record.isMissing { return false }
                    if hiddenIDs.contains(record.id) && !showHiddenInSearch { return false }
                    if !showSystemApplications && Self.isSystemApp(record) { return false }
                    return true
                }
                .map { LaunchpadDisplayItem(id: $0.id, title: $0.name, kind: .app($0), isHiddenApp: hiddenIDs.contains($0.id)) }]
        }

        return layoutStore.layout.pages.map { page in
            page.compactMap { item in
                switch item {
                case .app(let id):
                    guard let record = recordsByID[id], !record.isMissing else { return nil }
                    if layoutStore.layout.hiddenAppIDs.contains(id) { return nil }
                    if !showSystemApplications && Self.isSystemApp(record) { return nil }
                    return LaunchpadDisplayItem(id: id, title: record.name, kind: .app(record))
                case .folder(let id):
                    guard let folder = layoutStore.layout.folders.first(where: { $0.id == id }) else { return nil }
                    if !showSystemApplications && id == LayoutStore.appleFolderID { return nil }
                    var members = folder.items
                        .compactMap { recordsByID[$0] }
                        .filter { !layoutStore.layout.hiddenAppIDs.contains($0.id) && !$0.isMissing }
                    if !showSystemApplications {
                        members = members.filter { !Self.isSystemApp($0) }
                        if members.isEmpty { return nil }
                    }
                    return LaunchpadDisplayItem(id: id, title: folder.name, kind: .folder(folder), members: members)
                }
            }
        }
    }

    func applyScanResult(_ result: ScanResult) {
        appIndex.merge(scanResults: result.records)
        layoutStore.syncDirectoryFolders(result.directoryFolders)
        layoutStore.pruneApps(notIn: Set(result.records.map(\.id)))

        // Collect Apple's own apps into the managed "Apple" folder before adding
        // the rest to the grid, so freshly installed Apple apps land in the
        // folder rather than on a page. Apps already placed (on a page or in a
        // folder) are left where they are; appendNewApps skips anything already
        // foldered, so foldered Apple apps don't also land on the grid (a lone
        // Apple app below the folder threshold still appears normally).
        let appleIDs = result.records
            .filter { $0.bundleID?.hasPrefix("com.apple.") == true }
            .map(\.id)
        layoutStore.syncAppleFolder(appleAppIDs: appleIDs)

        let folderMemberIDs = Set(result.directoryFolders.flatMap(\.appIDs))
        let topLevelIDs = result.records.map(\.id).filter {
            !folderMemberIDs.contains($0)
        }
        layoutStore.appendNewApps(topLevelIDs)

        // Clean up folders that have been depleted (0 or 1 members) —
        // removes historical empty folders and dissolves single-app folders.
        layoutStore.dissolveEmptyFolders()
    }

    func launchSelected() -> LaunchResult? {
        guard let selectedItemID,
              let item = visiblePages.flatMap({ $0 }).first(where: { $0.id == selectedItemID }),
              case .app(let record) = item.kind else {
            return nil
        }
        return launcher.launch(record)
    }

    func bootstrapScan() {
        let preferences = (try? preferencesStore.load()) ?? .default
        showSystemApplications = preferences.showSystemApplications
        showHiddenInSearch = preferences.showHiddenInSearch
        let urls = preferences.scanDirectories.map { path in
            URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        }
        // Start from the saved layout so user folders and positions persist.
        layoutStore = LayoutStore(layout: layoutPersistence.load())
        // The rows-per-page follows the screen height; re-chunk layouts saved
        // with a different capacity (e.g. legacy 35-item pages, or pages from
        // another display) before merging in newly installed apps.
        // Force re-pagination when enlarged folders exist because the
        // cell-counting logic changed (enlarged = 4 cells) without changing
        // the stored capacity value.
        let hasEnlarged = !layoutStore.layout.enlargedFolderIDs.isEmpty
        layoutStore.repaginate(
            capacity: GridMetrics.pageCapacity(rows: gridRows),
            force: hasEnlarged
        )
        let result = scanner.scanAll(directories: urls)
        applyScanResult(result)
        persistLayout()
    }

    /// Handles dropping one item onto another in the grid. Dropping an app onto
    /// another app creates a folder containing both; dropping an app onto an
    /// existing folder adds it to that folder.
    func handleDrop(sourceID: String, onto target: LaunchpadDisplayItem) {
        // Only plain apps can be dragged for now (not directory/user folders).
        guard !Self.isFolderID(sourceID), sourceID != target.id else { return }

        // If the source was floating (extracted from a folder) it may not be on
        // any page yet — park it next to the target first so createFolder can
        // find a location.
        let onGrid = layoutStore.layout.pages.flatMap({ $0 }).contains(where: {
            if case .app(let id) = $0 { return id == sourceID }; return false
        })
        if !onGrid {
            var targetPage = currentPage
            var targetIndex = 0
            outer: for (pi, page) in layoutStore.layout.pages.enumerated() {
                for (ii, item) in page.enumerated() {
                    switch item {
                    case .app(let id) where id == target.id:
                        targetPage = pi; targetIndex = ii; break outer
                    case .folder(let id) where id == target.id:
                        targetPage = pi; targetIndex = ii; break outer
                    default:
                        break
                    }
                }
            }
            layoutStore.insertApp(appID: sourceID, toPage: targetPage, atIndex: targetIndex)
        }

        switch target.kind {
        case .app:
            let name = defaultFolderName()
            _ = layoutStore.createFolder(name: name, appIDs: [sourceID, target.id], now: Date())
        case .folder(let folder):
            layoutStore.addAppToFolder(appID: sourceID, folderID: folder.id)
        }
        // Do NOT repaginate / compact here — merging into a folder must leave
        // empty slots on the current page (Launchpad behaviour). Gaps are only
        // filled by "整理桌面" or when dragging an app *out* onto a page that
        // still has room.
        persistLayout()
    }

    func renameFolder(id: String, name: String) {
        layoutStore.renameFolder(id: id, name: name)
        persistLayout()
    }

    func reorderInFolder(folderID: String, appID: String, toIndex: Int) {
        layoutStore.reorderFolderItem(folderID: folderID, appID: appID, toIndex: toIndex)
        persistLayout()
    }

    func refreshOpenFolder() {
        guard let folder = openFolder, case .folder(let f) = folder.kind else { return }
        guard let updated = layoutStore.layout.folders.first(where: { $0.id == f.id }) else { return }
        let recordsByID = appIndex.records
        let members = updated.items
            .compactMap { recordsByID[$0] }
            .filter { !layoutStore.layout.hiddenAppIDs.contains($0.id) && !$0.isMissing }
        openFolder = LaunchpadDisplayItem(id: updated.id, title: updated.name, kind: .folder(updated), members: members)
    }

    /// Moves an app's bundle to the system Trash (recoverable) and, once that
    /// succeeds, removes it from the grid and folders and persists the layout.
    func moveToTrash(_ itemID: String) async {
        guard let record = appIndex.records[itemID] else { return }
        let success = await trasher.moveToTrash(path: record.path)
        guard success else { return }
        layoutStore.removeAppEverywhere(record.id)
        persistLayout()
    }

    /// Compacts all pages forward, filling gaps left by apps moved into
    /// folders or trashed, then persists. Triggered by "整理桌面".
    func tidyGrid() {
        layoutStore.compactPages()
        persistLayout()
    }

    func enlargeFolder(id: String) {
        layoutStore.enlargeFolder(id: id)
        // Enlarged = 4 cells; force overflow so we never paint a 5th row.
        layoutStore.repaginate(
            capacity: GridMetrics.pageCapacity(rows: gridRows),
            force: true
        )
        persistLayout()
    }

    func shrinkFolder(id: String) {
        layoutStore.shrinkFolder(id: id)
        layoutStore.repaginate(
            capacity: GridMetrics.pageCapacity(rows: gridRows),
            force: true
        )
        persistLayout()
    }

    func hideApp(id: String) {
        layoutStore.hideApp(id: id)
        persistLayout()
    }

    func unhideApp(id: String) {
        layoutStore.unhideApp(id: id)
        persistLayout()
    }

    /// Moves an app **or folder** to a new grid slot (reorder / insert only).
    /// Folders never merge with anything — they only change position.
    func moveAppInGrid(sourceID: String, targetPage: Int, targetIndex: Int) {
        layoutStore.moveItem(id: sourceID, toPage: targetPage, index: targetIndex)
        // Only push overflow forward if this page now exceeds capacity —
        // never pull items from later pages to fill holes.
        layoutStore.enforcePageCapacity()
        persistLayout()
    }

    /// Mid-drag live reorder: moves the item without persisting.
    /// Called on every cell-boundary crossing during drag.
    func liveReorder(draggedID: String, toIndex: Int, page: Int) {
        layoutStore.moveItem(id: draggedID, toPage: page, index: toIndex)
    }

    /// Mid-drag live reorder within a folder: moves the member without persisting.
    func liveReorderInFolder(folderID: String, appID: String, toIndex: Int) {
        layoutStore.reorderFolderItem(folderID: folderID, appID: appID, toIndex: toIndex)
        refreshOpenFolder()
    }

    /// Removes an app from its folder and places it at an explicit grid slot.
    @discardableResult
    func removeAppFromFolder(appID: String, toPage: Int? = nil, atIndex: Int? = nil) -> Bool {
        let page = toPage ?? max(0, currentPage)
        let pageItems = layoutStore.layout.pages.indices.contains(page)
            ? layoutStore.layout.pages[page].count
            : 0
        let dissolved = layoutStore.removeAppFromFolder(
            appID: appID,
            toPage: page,
            atIndex: atIndex ?? pageItems
        )
        persistLayout()
        return dissolved
    }

    /// Mid-drag: pull the app out of the open folder, close the popup, and
    /// keep a floating ghost under the pointer. Does **not** place on the grid yet.
    func beginFloatingDragOut(appID: String, at point: CGPoint) {
        guard let record = appIndex.records[appID] else { return }
        DiagLog.write("beginFloatingDragOut appID=\(appID) — closing folder")
        _ = layoutStore.extractAppFromFolder(appID)
        openFolder = nil
        floatingDragApp = record
        floatingDragPoint = point
        editDragID = appID
        persistLayout()
    }

    /// Finalize a floating drag-out / grid drag.
    ///
    /// Rules:
    /// - **Folder source**: never merges; always reorder/insert only.
    /// - **App source**: merge only when overlap with target is **> 50%**.
    /// - Otherwise insert using cell occupancy + drag translation (accurate
    ///   even when an enlarged 2×2 folder is on the page).
    func resolveDrop(
        sourceID: String,
        at point: CGPoint,
        translation: CGSize = .zero,
        page: Int,
        sourceIndex: Int? = nil
    ) {
        let sourceIsFolder = Self.isFolderID(sourceID)

        let draggedFrame: CGRect = {
            if let myFrame = tileFrames.first(where: { $0.id == sourceID })?.frame {
                return myFrame.offsetBy(
                    dx: editDragTranslation.width != 0 ? editDragTranslation.width : translation.width,
                    dy: editDragTranslation.height != 0 ? editDragTranslation.height : translation.height
                )
            }
            return CGRect(x: point.x - 52, y: point.y - 52, width: 104, height: 104)
        }()

        // Merge path — apps only, > 50% overlap.
        if !sourceIsFolder,
           let hit = bestOverlap(sourceID: sourceID, draggedFrame: draggedFrame),
           hit.ratio > 0.5 {
            handleDrop(sourceID: sourceID, onto: hit.item)
            clearFloatingDrag()
            return
        }

        // Insert / reorder.
        let onGrid = layoutStore.layout.pages.flatMap({ $0 }).contains { item in
            switch item {
            case .app(let id): return id == sourceID
            case .folder(let id): return id == sourceID
            }
        }

        // Prefer layout-page index of the source (visible index can diverge when
        // hidden/missing apps are filtered from the display list).
        let layoutSrcIndex = layoutIndex(of: sourceID, on: page)

        let index: Int
        if let layoutSrcIndex, onGrid {
            index = insertIndexByCellDelta(
                sourceID: sourceID,
                sourceIndex: layoutSrcIndex,
                translation: translation,
                page: page
            )
        } else {
            index = insertIndexByPoint(point: point, page: page, excluding: sourceID)
        }

        if onGrid {
            moveAppInGrid(sourceID: sourceID, targetPage: page, targetIndex: index)
        } else if !sourceIsFolder {
            layoutStore.insertApp(appID: sourceID, toPage: page, atIndex: index)
            persistLayout()
        }
        clearFloatingDrag()
    }

    func clearFloatingDrag() {
        floatingDragApp = nil
        floatingDragPoint = .zero
        editDragID = nil
        editDragTranslation = .zero
    }

    private func isAppInNoFolder(_ appID: String) -> Bool {
        !layoutStore.layout.folders.contains { $0.items.contains(appID) }
    }

    /// Best overlapping tile and its overlap ratio (area of intersection /
    /// area of the dragged rect). Caller decides the merge threshold (50%).
    private func bestOverlap(
        sourceID: String,
        draggedFrame: CGRect
    ) -> (item: LaunchpadDisplayItem, ratio: CGFloat)? {
        let draggedArea = max(1, draggedFrame.width * draggedFrame.height)
        var best: (item: LaunchpadDisplayItem, ratio: CGFloat)?
        for info in tileFrames where info.id != sourceID {
            let overlap = draggedFrame.intersection(info.frame)
            let area = max(0, overlap.width * overlap.height)
            let ratio = area / draggedArea
            guard ratio > 0 else { continue }
            guard let item = visiblePages.flatMap({ $0 }).first(where: { $0.id == info.id }) else {
                continue
            }
            if best == nil || ratio > best!.ratio {
                best = (item, ratio)
            }
        }
        return best
    }

    /// Insert index from drag translation using the same 7-column occupancy
    /// map as `LaunchpadGridLayout` (handles enlarged 2×2 folders correctly).
    /// Returned index is valid for `moveItem` (remove-then-insert).
    private func insertIndexByCellDelta(
        sourceID: String,
        sourceIndex: Int,
        translation: CGSize,
        page: Int
    ) -> Int {
        guard layoutStore.layout.pages.indices.contains(page) else { return 0 }
        let pageItems = layoutStore.layout.pages[page]
        guard sourceIndex >= 0, sourceIndex < pageItems.count else {
            return insertIndexByPoint(point: .zero, page: page, excluding: sourceID)
        }

        let positions = cellPositions(for: pageItems)
        guard sourceIndex < positions.count else { return 0 }

        let cellW = GridMetrics.tileWidth + GridMetrics.columnSpacing
        let cellH = GridMetrics.tileHeight + GridMetrics.rowSpacing
        let colDelta = Int((translation.width / cellW).rounded())
        let rowDelta = Int((translation.height / cellH).rounded())

        let (srcCol, srcRow) = positions[sourceIndex]
        let targetCol = max(0, min(GridMetrics.columns - 1, srcCol + colDelta))
        let targetRow = max(0, srcRow + rowDelta)

        // Among remaining items (source removed), insert before the first whose
        // top-left cell is at/after (targetCol, targetRow) in reading order.
        var rank = 0
        for (i, _) in pageItems.enumerated() where i != sourceIndex {
            let (c, r) = positions[i]
            if r > targetRow || (r == targetRow && c >= targetCol) {
                return rank
            }
            rank += 1
        }
        return rank // append
    }

    /// Floating drag (out of folder): insert by pointer among remaining tiles.
    ///
    /// Row selection uses the band that **contains** the pointer (not nearest
    /// midY — that preferred the row above when the pointer was in the upper
    /// half of the target row). Within the row, insert by X only.
    private func insertIndexByPoint(point: CGPoint, page: Int, excluding sourceID: String?) -> Int {
        let pageItems = visiblePages.indices.contains(page) ? visiblePages[page] : []
        var ordered: [(rank: Int, rect: CGRect)] = []
        for item in pageItems {
            if item.id == sourceID { continue }
            guard let info = tileFrames.first(where: { $0.id == item.id }) else { continue }
            ordered.append((ordered.count, info.frame))
        }
        guard !ordered.isEmpty else { return 0 }

        // Cluster into visual rows by similar top edge.
        let rowTol = max(24.0, GridMetrics.tileHeight * 0.45)
        var rows: [[(rank: Int, rect: CGRect)]] = []
        for entry in ordered {
            if var last = rows.last, let sample = last.first,
               abs(sample.rect.minY - entry.rect.minY) < rowTol {
                last.append(entry)
                rows[rows.count - 1] = last
            } else {
                rows.append([entry])
            }
        }

        // 1) Prefer the row whose vertical span contains the pointer.
        // 2) Else the first row whose maxY is below the pointer (pointer in gap
        //    above that row → use that row).
        // 3) Else nearest midY.
        var bestRow: Int?
        for (ri, row) in rows.enumerated() {
            let minY = row.map(\.rect.minY).min() ?? 0
            let maxY = row.map(\.rect.maxY).max() ?? 0
            if point.y >= minY && point.y <= maxY {
                bestRow = ri
                break
            }
        }
        if bestRow == nil {
            for (ri, row) in rows.enumerated() {
                let minY = row.map(\.rect.minY).min() ?? 0
                if point.y < minY {
                    bestRow = ri
                    break
                }
            }
        }
        if bestRow == nil {
            var bestDist = CGFloat.greatestFiniteMagnitude
            var ri = rows.count - 1
            for (i, row) in rows.enumerated() {
                let midY = row.map(\.rect.midY).reduce(0, +) / CGFloat(max(1, row.count))
                let d = abs(point.y - midY)
                if d < bestDist {
                    bestDist = d
                    ri = i
                }
            }
            bestRow = ri
        }

        let row = rows[bestRow!].sorted { $0.rect.midX < $1.rect.midX }
        for cell in row {
            if point.x < cell.rect.midX {
                return cell.rank
            }
        }
        if let last = row.last {
            return last.rank + 1
        }
        return ordered.count
    }

    private func layoutIndex(of sourceID: String, on page: Int) -> Int? {
        guard layoutStore.layout.pages.indices.contains(page) else { return nil }
        for (i, item) in layoutStore.layout.pages[page].enumerated() {
            switch item {
            case .app(let id) where id == sourceID: return i
            case .folder(let id) where id == sourceID: return i
            default: break
            }
        }
        return nil
    }

    /// Top-left grid cell for each item on a page (matches LaunchpadGridLayout).
    private func cellPositions(for pageItems: [LaunchpadItem]) -> [(col: Int, row: Int)] {
        var occupied = Set<String>()
        var col = 0
        var row = 0
        var result: [(Int, Int)] = []
        let columns = GridMetrics.columns

        func key(_ c: Int, _ r: Int) -> String { "\(c),\(r)" }

        for item in pageItems {
            while occupied.contains(key(col, row)) {
                col += 1
                if col >= columns { col = 0; row += 1 }
            }
            let isEnlarged: Bool = {
                if case .folder(let id) = item {
                    return layoutStore.layout.enlargedFolderIDs.contains(id)
                }
                return false
            }()

            result.append((col, row))
            if isEnlarged, col + 1 < columns {
                occupied.insert(key(col, row))
                occupied.insert(key(col + 1, row))
                occupied.insert(key(col, row + 1))
                occupied.insert(key(col + 1, row + 1))
                col += 2
            } else {
                occupied.insert(key(col, row))
                col += 1
            }
            if col >= columns { col = 0; row += 1 }
        }
        return result
    }

    func appRecord(id: String) -> AppRecord? {
        appIndex.records[id]
    }

    /// All currently-hidden app records, for the settings management list.
    var hiddenApps: [AppRecord] {
        layoutStore.layout.hiddenAppIDs.compactMap { appIndex.records[$0] }
    }

    func isFolderEnlarged(_ id: String) -> Bool {
        layoutStore.isEnlarged(id)
    }

    var enlargedFolderIDs: Set<String> {
        layoutStore.layout.enlargedFolderIDs
    }

    private func defaultFolderName() -> String {
        let base = "新文件夹"
        let existing = Set(layoutStore.layout.folders.map(\.name))
        guard existing.contains(base) else { return base }
        var suffix = 2
        while existing.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    private static func isFolderID(_ id: String) -> Bool {
        id.hasPrefix("folder:") || id.hasPrefix("dir:")
    }

    private static func isSystemApp(_ record: AppRecord) -> Bool {
        record.source == .systemApplications || record.bundleID?.hasPrefix("com.apple.") == true
    }

    private func persistLayout() {
        layoutPersistence.save(layoutStore.layout)
    }
}
