import AppKit
import Foundation

/// Moves app bundles to the Trash. Deletion is always recoverable: bundles are
/// recycled through the system Trash rather than removed permanently.
protocol AppTrashing: Sendable {
    func moveToTrash(path: String) async -> Bool
}

struct SystemAppTrasher: AppTrashing {
    func moveToTrash(path: String) async -> Bool {
        let url = URL(fileURLWithPath: path)
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle([url]) { newURLs, error in
                let success = error == nil && !(newURLs ?? [:]).isEmpty
                continuation.resume(returning: success)
            }
        }
    }
}
