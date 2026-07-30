import Foundation
import Testing
@testable import iLaunch

/// Regression test: build/verify scripts must be able to point the app at an
/// isolated data directory instead of the user's real
/// ~/Library/Application Support/iLaunch — a prior incident had
/// automated verification launches read/write the user's real layout.json.
@Test func applicationSupportDirectoryHonorsDataDirOverride() throws {
    let override = FileManager.default.temporaryDirectory
        .appendingPathComponent("ilaunch-paths-test-\(UUID().uuidString)")
    defer {
        unsetenv(iLaunchPaths.dataDirOverrideEnvKey)
        try? FileManager.default.removeItem(at: override)
    }
    setenv(iLaunchPaths.dataDirOverrideEnvKey, override.path, 1)

    let resolved = try iLaunchPaths.applicationSupportDirectory()

    #expect(resolved.path == override.path)
    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: override.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
}

/// Regression: an empty override must NOT silently fall through to the real
/// ~/Library/Application Support/iLaunch directory. `swift test` runs
/// inside a process named `swiftpm-testing-helper`, so without a real
/// override this must throw — several tests forgetting to pass an isolated
/// layoutPersistence:/preferencesStore: silently read and overwrote the
/// user's actual layout.json across many `swift test` runs before this
/// guard existed.
@Test func applicationSupportDirectoryThrowsUnderTestHostWithoutOverride() throws {
    defer { unsetenv(iLaunchPaths.dataDirOverrideEnvKey) }
    setenv(iLaunchPaths.dataDirOverrideEnvKey, "", 1)

    #expect(throws: RealDataDirectoryAccessedFromTestHostError.self) {
        try iLaunchPaths.applicationSupportDirectory()
    }
}
