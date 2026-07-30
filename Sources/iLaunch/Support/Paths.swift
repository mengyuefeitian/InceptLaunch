import Foundation

struct RealDataDirectoryAccessedFromTestHostError: Error, CustomStringConvertible {
    var description: String {
        "iLaunchPaths.applicationSupportDirectory() was called from a " +
        "`swift test` host process without ILAUNCH_DATA_DIR set. A test " +
        "that constructs LayoutPersistenceStore()/PreferencesStore() with no " +
        "override — or a LaunchpadViewModel without passing layoutPersistence:/" +
        "preferencesStore: — would otherwise silently read and overwrite the " +
        "real ~/Library/Application Support/iLaunch/ directory. This has " +
        "happened before and destroyed real user data across many test runs. " +
        "Pass an isolated fileStore/URL explicitly instead."
    }
}

enum iLaunchPaths {
    /// Overrides the Application Support directory (layout.json,
    /// preferences.json, logs) when set — so local build/verify scripts can
    /// point at a throwaway directory instead of the user's real data.
    /// Never set in the packaged app's normal launch path.
    static let dataDirOverrideEnvKey = "ILAUNCH_DATA_DIR"

    /// `swift test` (swift-testing) runs test code inside a process named
    /// `swiftpm-testing-helper`. Any code running there must never touch the
    /// user's real data directory, even implicitly via a default parameter a
    /// test author forgot to override — see the incident this guards
    /// against in `RealDataDirectoryAccessedFromTestHostError`.
    private static var isRunningUnderSwiftTestHost: Bool {
        ProcessInfo.processInfo.processName == "swiftpm-testing-helper"
    }

    static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment[dataDirOverrideEnvKey], !overridePath.isEmpty {
            let directory = URL(fileURLWithPath: overridePath, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
        if isRunningUnderSwiftTestHost {
            throw RealDataDirectoryAccessedFromTestHostError()
        }
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(AppIdentity.name, isDirectory: true)
        // One-time migration from the pre-rename product name so existing
        // layout.json / preferences.json / logs are not abandoned.
        let legacyDirectory = base.appendingPathComponent("InceptLaunch", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path),
           fileManager.fileExists(atPath: legacyDirectory.path) {
            try? fileManager.moveItem(at: legacyDirectory, to: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
