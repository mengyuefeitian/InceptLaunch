import Foundation

final class PreferencesStore {
    private let fileStore: JSONFileStore<UserPreferences>

    init(fileStore: JSONFileStore<UserPreferences>? = nil) {
        if let fileStore {
            self.fileStore = fileStore
        } else {
            let directory = (try? InceptLaunchPaths.applicationSupportDirectory())
                ?? FileManager.default.temporaryDirectory
            self.fileStore = JSONFileStore<UserPreferences>(
                url: directory.appendingPathComponent("preferences.json")
            )
        }
    }

    func load() throws -> UserPreferences {
        try fileStore.load(default: .default)
    }

    func save(_ preferences: UserPreferences) throws {
        try fileStore.save(preferences)
    }
}
