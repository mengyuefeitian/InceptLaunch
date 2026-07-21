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

        let folderMemberIDs = Set(result.directoryFolders.flatMap(\.appIDs))
        let topLevelIDs = result.records.map(\.id).filter { !folderMemberIDs.contains($0) }
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
        layoutStore.repaginate(capacity: GridMetrics.pageCapacity(rows: gridRows))
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
