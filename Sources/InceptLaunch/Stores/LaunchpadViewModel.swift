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
    /// LaunchpadGridView. Used by the dismiss monitor to distinguish tile
    /// clicks from empty-space clicks.
    var tileFrames: [CGRect] = []

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
            return [matcher.ranked(query: searchText, records: Array(recordsByID.values))
                .filter { !$0.isHidden && !$0.isMissing }
                .map { LaunchpadDisplayItem(id: $0.id, title: $0.name, kind: .app($0)) }]
        }

        return layoutStore.layout.pages.map { page in
            page.compactMap { item in
                switch item {
                case .app(let id):
                    guard let record = recordsByID[id], !record.isHidden, !record.isMissing else { return nil }
                    return LaunchpadDisplayItem(id: id, title: record.name, kind: .app(record))
                case .folder(let id):
                    guard let folder = layoutStore.layout.folders.first(where: { $0.id == id }) else { return nil }
                    let members = folder.items
                        .compactMap { recordsByID[$0] }
                        .filter { !$0.isHidden && !$0.isMissing }
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

        switch target.kind {
        case .app:
            let name = defaultFolderName()
            _ = layoutStore.createFolder(name: name, appIDs: [sourceID, target.id], now: Date())
        case .folder(let folder):
            layoutStore.addAppToFolder(appID: sourceID, folderID: folder.id)
        }
        persistLayout()
    }

    func renameFolder(id: String, name: String) {
        layoutStore.renameFolder(id: id, name: name)
        persistLayout()
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
        persistLayout()
    }

    func shrinkFolder(id: String) {
        layoutStore.shrinkFolder(id: id)
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

    /// Moves an app to a new position in the grid (used by edit-mode drag reorder).
    /// `targetPage` and `targetIndex` specify where to place it.
    func moveAppInGrid(sourceID: String, targetPage: Int, targetIndex: Int) {
        guard !Self.isFolderID(sourceID) else { return }
        layoutStore.moveItem(id: sourceID, toPage: targetPage, index: targetIndex)
        // Re-chunk pages so no page exceeds the screen-adaptive capacity
        // (e.g. 7×4 = 28 on 1080p); without this an insert into a full page
        // overflows into a 5th row.
        layoutStore.repaginate(
            capacity: GridMetrics.pageCapacity(rows: gridRows),
            force: true
        )
        persistLayout()
    }

    /// Removes an app from its folder and places it back on the grid.
    func removeAppFromFolder(appID: String) {
        layoutStore.removeAppFromFolder(appID: appID)
        persistLayout()
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

    private func persistLayout() {
        layoutPersistence.save(layoutStore.layout)
    }
}
