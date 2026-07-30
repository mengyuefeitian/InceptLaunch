import AppKit
import Foundation

enum LaunchResult: Equatable {
    case launched
    case missingPath
    case failed
}

protocol WorkspaceLaunching {
    func openApplication(at url: URL) -> Bool
}

struct SystemWorkspaceLauncher: WorkspaceLaunching {
    func openApplication(at url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

struct AppLauncher {
    let workspace: WorkspaceLaunching

    init(workspace: WorkspaceLaunching = SystemWorkspaceLauncher()) {
        self.workspace = workspace
    }

    func launch(_ record: AppRecord) -> LaunchResult {
        guard FileManager.default.fileExists(atPath: record.path) else {
            return .missingPath
        }

        let opened = workspace.openApplication(at: URL(fileURLWithPath: record.path))
        return opened ? .launched : .failed
    }
}
