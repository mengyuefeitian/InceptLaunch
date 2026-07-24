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
                if let image = imageFromURL(url) {
                    return image
                }
            }
        }

        // Fallback: try all screens
        for screen in NSScreen.screens {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                if let image = imageFromURL(url) {
                    return image
                }
            }
        }

        // Fallback: read from com.apple.wallpaper plist
        if let image = userDesktopPicture() {
            return image
        }

        // Fallback: scan known wallpaper directories for system wallpapers
        for dir in wallpaperDirectories {
            if let image = findBestWallpaper(in: dir) {
                return image
            }
        }

        return nil
    }

    /// Loads an image from a URL, handling both single images and folders.
    private static func imageFromURL(_ url: URL) -> NSImage? {
        let path = url.path

        // Check if it's a directory (folder of wallpapers)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            // Pick the most recent image from the folder
            return mostRecentImage(in: path)
        }

        // Single image file
        if let image = NSImage(contentsOf: url) {
            return image
        }

        return nil
    }

    /// Finds the most recently modified image in a directory.
    private static func mostRecentImage(in directory: String) -> NSImage? {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        let imageExtensions = ["heic", "jpg", "jpeg", "png", "tiff", "gif"]

        // Filter to image files only
        let imageFiles = contents.filter { file in
            let ext = (file as NSString).pathExtension.lowercased()
            return imageExtensions.contains(ext)
        }

        guard !imageFiles.isEmpty else { return nil }

        // Sort by modification date (most recent first)
        let sorted = imageFiles.sorted { a, b in
            let pathA = (directory as NSString).appendingPathComponent(a)
            let pathB = (directory as NSString).appendingPathComponent(b)
            let dateA = (try? FileManager.default.attributesOfItem(atPath: pathA)[.modificationDate] as? Date) ?? .distantPast
            let dateB = (try? FileManager.default.attributesOfItem(atPath: pathB)[.modificationDate] as? Date) ?? .distantPast
            return dateA > dateB
        }

        // Return the most recent image
        let fullPath = (directory as NSString).appendingPathComponent(sorted.first!)
        return NSImage(contentsOfFile: fullPath)
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

            // Walk the plist looking for image paths or folders
            if let image = findWallpaperPath(in: plist, home: home) {
                return image
            }
        }

        return nil
    }

    /// Recursively searches a plist for wallpaper file paths or folders.
    private static func findWallpaperPath(in value: Any, home: String) -> NSImage? {
        if let str = value as? String {
            // Handle file:// URLs
            let path: String
            if str.hasPrefix("file://") {
                path = str.replacingOccurrences(of: "file://", with: "")
            } else if str.hasPrefix("~") {
                path = str.replacingOccurrences(of: "~", with: home)
            } else {
                path = str
            }

            // Check if it's a directory
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // It's a folder of wallpapers
                    return mostRecentImage(in: path)
                } else {
                    // It's a single image
                    return NSImage(contentsOfFile: path)
                }
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
