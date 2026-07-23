import AppKit

/// Captures the current desktop wallpaper image for use as the overlay background.
/// `.ultraThinMaterial` doesn't work on borderless windows above the desktop layer,
/// so we need to capture the actual wallpaper image.
enum DesktopWallpaperCapture {
    /// Returns the current desktop wallpaper as an NSImage, or nil if unavailable.
    static var currentImage: NSImage? {
        guard let screen = NSScreen.main else { return nil }
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        return NSImage(contentsOf: url)
    }
}
