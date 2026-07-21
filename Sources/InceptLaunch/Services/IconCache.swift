import AppKit
import Foundation

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]

    func icon(for record: AppRecord) async -> NSImage {
        if let cached = cache[record.iconCacheKey] {
            return cached
        }
        let path = record.path
        let image = await Task.detached(priority: .userInitiated) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 144, height: 144)
            return icon
        }.value
        cache[record.iconCacheKey] = image
        return image
    }
}
