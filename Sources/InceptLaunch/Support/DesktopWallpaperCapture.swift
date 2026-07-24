import AppKit

/// Captures the current desktop wallpaper image for use as the overlay background.
/// `.ultraThinMaterial` doesn't work on borderless windows above the desktop layer,
/// so we need to capture the actual wallpaper image.
enum DesktopWallpaperCapture {
    /// Returns the current desktop wallpaper as an NSImage, or nil if unavailable.
    static var currentImage: NSImage? {
        // Try NSWorkspace API first (works on most macOS versions)
        if let screen = NSScreen.main {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        // Fallback: try all screens
        for screen in NSScreen.screens {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        // Fallback: try known desktop picture paths across macOS versions
        let knownPaths = [
            "/Library/Desktop Pictures/Sonoma.heic",
            "/Library/Desktop Pictures/Big Sur.heic",
            "/Library/Desktop Pictures/Ventura.heic",
            "/Library/Desktop Pictures/Monterey.heic",
            "/System/Library/Desktop Pictures/Sonoma.heic",
            "/System/Library/Desktop Pictures/Big Sur.heic",
        ]
        for path in knownPaths {
            if let image = NSImage(contentsOfFile: path) {
                return image
            }
        }

        // Fallback: scan Desktop Pictures directories for any image
        for dir in ["/Library/Desktop Pictures", "/System/Library/Desktop Pictures"] {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                // Prefer .heic files, then .jpg, then .png
                let sorted = contents.sorted { a, b in
                    let priority: (String) -> Int = {
                        if $0.hasSuffix(".heic") { return 0 }
                        if $0.hasSuffix(".jpg") { return 1 }
                        if $0.hasSuffix(".png") { return 2 }
                        return 3
                    }
                    return priority(a) < priority(b)
                }
                for file in sorted {
                    if file.hasSuffix(".heic") || file.hasSuffix(".jpg") || file.hasSuffix(".png") {
                        let fullPath = (dir as NSString).appendingPathComponent(file)
                        if let image = NSImage(contentsOfFile: fullPath) {
                            return image
                        }
                    }
                }
            }
        }

        // Fallback: try to read from macOS wallpaper database
        if let image = wallpaperFromDatabase() {
            return image
        }

        return nil
    }

    /// Attempts to find the wallpaper path from the macOS desktop database.
    private static func wallpaperFromDatabase() -> NSImage? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // macOS stores wallpaper info in various locations depending on version
        let dbPaths = [
            "\(home)/Library/Application Support/Dock/desktoppicture.db",
            "\(home)/Library/Application Support/com.apple.wallpaper/Store/Index.plist",
        ]

        for dbPath in dbPaths {
            if FileManager.default.fileExists(atPath: dbPath) {
                // Try to extract image path from the plist
                if let data = FileManager.default.contents(atPath: dbPath),
                   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                    // Walk the plist looking for image paths
                    if let image = findImagePath(in: plist, home: home) {
                        return image
                    }
                }
            }
        }

        return nil
    }

    /// Recursively searches a plist for image file paths.
    private static func findImagePath(in value: Any, home: String) -> NSImage? {
        if let str = value as? String {
            let path = str.hasPrefix("~") ? str.replacingOccurrences(of: "~", with: home) : str
            if (path.hasSuffix(".heic") || path.hasSuffix(".jpg") || path.hasSuffix(".png")),
               FileManager.default.fileExists(atPath: path),
               let image = NSImage(contentsOfFile: path) {
                return image
            }
        } else if let dict = value as? [String: Any] {
            for (_, v) in dict {
                if let img = findImagePath(in: v, home: home) { return img }
            }
        } else if let arr = value as? [Any] {
            for elem in arr {
                if let img = findImagePath(in: elem, home: home) { return img }
            }
        }
        return nil
    }
}
