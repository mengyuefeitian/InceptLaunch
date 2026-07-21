import AppKit
import Foundation

struct IconCache {
    func icon(for record: AppRecord) -> NSImage {
        NSWorkspace.shared.icon(forFile: record.path)
    }
}
