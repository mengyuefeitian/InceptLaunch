import Foundation

/// Persists the user's layout (page arrangement and folders) to Application
/// Support so it survives relaunches.
struct LayoutPersistenceStore {
    private let fileStore: JSONFileStore<LaunchpadLayout>

    init(fileStore: JSONFileStore<LaunchpadLayout>? = nil) {
        if let fileStore {
            self.fileStore = fileStore
        } else {
            let directory = (try? iLaunchPaths.applicationSupportDirectory())
                ?? FileManager.default.temporaryDirectory
            self.fileStore = JSONFileStore<LaunchpadLayout>(
                url: directory.appendingPathComponent("layout.json")
            )
        }
    }

    func load() -> LaunchpadLayout {
        (try? fileStore.load(default: .empty)) ?? .empty
    }

    func save(_ layout: LaunchpadLayout) {
        try? fileStore.save(layout)
    }
}
