import AppKit

/// Switches the app's Dock icon at runtime by loading the selected icon
/// variant from the bundle's Resources/Icons directory.
enum IconSwitcher {
    /// Applies the given icon style to the running app (Dock icon only;
    /// Finder icon requires a bundle rebuild).
    @MainActor
    static func apply(_ style: UserPreferences.AppIconStyle) {
        let name = style.resourceName
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns"),
              let image = NSImage(contentsOf: url) else {
            // Fallback: try the default icon
            if let fallback = NSImage(named: "iLaunch") {
                NSApp.applicationIconImage = fallback
            }
            return
        }
        NSApp.applicationIconImage = image
    }
}
