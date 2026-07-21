import Foundation

struct UserPreferences: Codable, Equatable {
    enum OverlayDisplayMode: String, Codable, Equatable {
        case activeDisplay
        case mouseDisplay
        case allDisplays
    }

    var hotKey: String
    var launchAtLogin: Bool
    var showMenuBarIcon: Bool
    var showDockIcon: Bool
    var backgroundBlur: Double
    var reduceMotion: Bool
    var showSystemApplications: Bool
    var overlayDisplayMode: OverlayDisplayMode
    var scanDirectories: [String]

    static let `default` = UserPreferences(
        hotKey: "option+space",
        launchAtLogin: false,
        showMenuBarIcon: true,
        showDockIcon: true,
        backgroundBlur: 0.72,
        reduceMotion: false,
        showSystemApplications: true,
        overlayDisplayMode: .activeDisplay,
        scanDirectories: [
            "/Applications",
            "~/Applications",
            "/System/Applications",
            "/System/Library/CoreServices/Applications"
        ]
    )
}
