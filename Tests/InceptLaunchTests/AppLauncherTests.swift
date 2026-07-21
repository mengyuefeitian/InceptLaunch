import Foundation
import Testing
@testable import InceptLaunch

@Test func missingPathReturnsFailureWithoutOpeningWorkspace() {
    let workspace = MockWorkspace()
    let launcher = AppLauncher(workspace: workspace)
    let record = AppRecord(
        id: "bundle:missing",
        bundleID: "missing",
        name: "Missing",
        localizedName: nil,
        path: "/definitely/missing/Missing.app",
        iconCacheKey: "missing",
        version: nil,
        source: .customDirectory,
        isHidden: false,
        isMissing: false,
        lastSeenAt: Date(),
        lastLaunchedAt: nil
    )
    #expect(launcher.launch(record) == .missingPath)
    #expect(workspace.openedURLs == [])
}

final class MockWorkspace: WorkspaceLaunching {
    var openedURLs: [URL] = []
    func openApplication(at url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}
