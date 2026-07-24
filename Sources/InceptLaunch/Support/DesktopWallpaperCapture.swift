import AppKit

/// Captures the current desktop wallpaper image for use as the overlay background.
/// `.ultraThinMaterial` doesn't work on borderless windows above the desktop layer,
/// so we need to capture the actual wallpaper image.
enum DesktopWallpaperCapture {
    /// Known directories where macOS stores system wallpapers.
    private static let wallpaperDirectories = [
        "/Library/Desktop Pictures",
        "/System/Library/Desktop Pictures",
    ]

    /// Returns the current desktop wallpaper as an NSImage, or nil if unavailable.
    static var currentImage: NSImage? {
        // Primary: NSWorkspace API (works on most macOS versions)
        if let screen = NSScreen.main {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                // Only accept images from known wallpaper directories
                let path = url.path
                if isWallpaperPath(path), let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        // Fallback: try all screens
        for screen in NSScreen.screens {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                let path = url.path
                if isWallpaperPath(path), let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        // Fallback: scan known wallpaper directories for system wallpapers
        for dir in wallpaperDirectories {
            if let image = findBestWallpaper(in: dir) {
                return image
            }
        }

        // Fallback: try user's custom desktop picture from preferences
        if let image = userDesktopPicture() {
            return image
        }

        return nil
    }

    /// Checks if a path is from a known wallpaper directory.
    private static func isWallpaperPath(_ path: String) -> Bool {
        for dir in wallpaperDirectories {
            if path.hasPrefix(dir) { return true }
        }
        return false
    }

    /// Finds the best wallpaper image in a directory.
    /// Prefers named system wallpapers (Sonoma, Ventura, etc.) over generic ones.
    private static func findBestWallpaper(in directory: String) -> NSImage? {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        // Priority order: named system wallpapers first, then any .heic/.jpg/.png
        let systemNames = ["Sonoma", "Ventura", "Monterey", "Big Sur", "Catalina", "Mojave"]
        let extensions = ["heic", "jpg", "jpeg", "png"]

        // First pass: look for named system wallpapers
        for name in systemNames {
            for ext in extensions {
                let filename = "\(name).\(ext)"
                if contents.contains(filename) {
                    let fullPath = (directory as NSString).appendingPathComponent(filename)
                    if let image = NSImage(contentsOfFile: fullPath) {
                        return image
                    }
                }
            }
        }

        // Second pass: look for any .heic file (modern macOS wallpaper format)
        for file in contents {
            if file.hasSuffix(".heic") {
                let fullPath = (directory as NSString).appendingPathComponent(file)
                if let image = NSImage(contentsOfFile: fullPath) {
                    return image
                }
            }
        }

        // Third pass: look for any .jpg/.png file
        for file in contents {
            if file.hasSuffix(".jpg") || file.hasSuffix(".jpeg") || file.hasSuffix(".png") {
                let fullPath = (directory as NSString).appendingPathComponent(file)
                if let image = NSImage(contentsOfFile: fullPath) {
                    return image
                }
            }
        }

        return nil
    }

    /// Tries to find the user's custom desktop picture from macOS preferences.
    private static func userDesktopPicture() -> NSImage? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // macOS stores wallpaper info in various locations
        let plistPaths = [
            "\(home)/Library/Application Support/com.apple.wallpaper/Store/Index.plist",
        ]

        for plistPath in plistPaths {
            guard FileManager.default.fileExists(atPath: plistPath),
                  let data = FileManager.default.contents(atPath: plistPath),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
                continue
            }

            // Walk the plist looking for image paths in wallpaper directories
            if let image = findWallpaperPath(in: plist, home: home) {
                return image
            }
        }

        return nil
    }

    /// Recursively searches a plist for wallpaper file paths in known directories.
    private static func findWallpaperPath(in value: Any, home: String) -> NSImage? {
        if let str = value as? String {
            let path = str.hasPrefix("~") ? str.replacingOccurrences(of: "~", with: home) : str
            // Only accept paths from known wallpaper directories
            if isWallpaperPath(path),
               FileManager.default.fileExists(atPath: path),
               let image = NSImage(contentsOfFile: path) {
                return image
            }
        } else if let dict = value as? [String: Any] {
            for (_, v) in dict {
                if let img = findWallpaperPath(in: v, home: home) { return img }
            }
        } else if let arr = value as? [Any] {
            for elem in arr {
                if let img = findWallpaperPath(in: elem, home: home) { return img }
            }
        }
        return nil
    }
}
