import Foundation

enum InceptLaunchPaths {
    /// Overrides the Application Support directory (layout.json,
    /// preferences.json, logs) when set — so local build/verify scripts can
    /// point at a throwaway directory instead of the user's real data.
    /// Never set in the packaged app's normal launch path.
    static let dataDirOverrideEnvKey = "INCEPTLAUNCH_DATA_DIR"

    static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment[dataDirOverrideEnvKey], !overridePath.isEmpty {
            let directory = URL(fileURLWithPath: overridePath, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(AppIdentity.name, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
