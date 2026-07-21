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
}

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

    init(
        appIndex: AppIndexStore = AppIndexStore(),
        layoutStore: LayoutStore = LayoutStore(),
        matcher: SearchMatcher = SearchMatcher(),
        launcher: AppLauncher = AppLauncher(),
        scanner: AppScanner = AppScanner(),
        preferencesStore: PreferencesStore = PreferencesStore()
    ) {
        self.appIndex = appIndex
        self.layoutStore = layoutStore
        self.matcher = matcher
        self.launcher = launcher
        self.scanner = scanner
        self.preferencesStore = preferencesStore
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
                    return LaunchpadDisplayItem(id: id, title: folder.name, kind: .folder(folder))
                }
            }
        }
    }

    func refreshFromScanResults(_ records: [AppRecord]) {
        appIndex.merge(scanResults: records)
        layoutStore.appendNewApps(records.map(\.id))
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
        let records = scanner.scan(directories: urls)
        refreshFromScanResults(records)
    }
}
