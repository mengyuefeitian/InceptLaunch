import Foundation

struct UserPreferences: Codable, Equatable {
    enum OverlayDisplayMode: String, Codable, Equatable {
        case activeDisplay
        case mouseDisplay
        case allDisplays
    }

    enum AppIconStyle: String, Codable, Equatable, CaseIterable {
        case iconD = "D"
        case icon01 = "icon01"
        case icon02 = "icon02"
        case icon03 = "icon03"

        var displayName: String {
            switch self {
            case .iconD: return "默认 (D)"
            case .icon01: return "图标 1"
            case .icon02: return "图标 2"
            case .icon03: return "图标 3"
            }
        }

        var resourceName: String {
            switch self {
            case .iconD: return "InceptLaunch-D"
            case .icon01: return "icon01"
            case .icon02: return "icon02"
            case .icon03: return "icon03"
            }
        }

        /// PNG thumbnail file name for the settings picker (bundled in Resources).
        var thumbnailName: String {
            switch self {
            case .iconD: return "InceptLaunch-D"
            case .icon01: return "icon01"
            case .icon02: return "icon02"
            case .icon03: return "icon03"
            }
        }
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
    var appIconStyle: AppIconStyle = .iconD

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
        ],
        appIconStyle: .iconD
    )

    private enum CodingKeys: String, CodingKey {
        case hotKey, launchAtLogin, showMenuBarIcon, showDockIcon
        case backgroundBlur, reduceMotion, showSystemApplications
        case overlayDisplayMode, scanDirectories, appIconStyle
    }

    init(hotKey: String, launchAtLogin: Bool, showMenuBarIcon: Bool, showDockIcon: Bool, backgroundBlur: Double, reduceMotion: Bool, showSystemApplications: Bool, overlayDisplayMode: OverlayDisplayMode, scanDirectories: [String], appIconStyle: AppIconStyle = .iconD) {
        self.hotKey = hotKey
        self.launchAtLogin = launchAtLogin
        self.showMenuBarIcon = showMenuBarIcon
        self.showDockIcon = showDockIcon
        self.backgroundBlur = backgroundBlur
        self.reduceMotion = reduceMotion
        self.showSystemApplications = showSystemApplications
        self.overlayDisplayMode = overlayDisplayMode
        self.scanDirectories = scanDirectories
        self.appIconStyle = appIconStyle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotKey = try c.decode(String.self, forKey: .hotKey)
        launchAtLogin = try c.decode(Bool.self, forKey: .launchAtLogin)
        showMenuBarIcon = try c.decode(Bool.self, forKey: .showMenuBarIcon)
        showDockIcon = try c.decode(Bool.self, forKey: .showDockIcon)
        backgroundBlur = try c.decode(Double.self, forKey: .backgroundBlur)
        reduceMotion = try c.decode(Bool.self, forKey: .reduceMotion)
        showSystemApplications = try c.decode(Bool.self, forKey: .showSystemApplications)
        overlayDisplayMode = try c.decode(OverlayDisplayMode.self, forKey: .overlayDisplayMode)
        scanDirectories = try c.decode([String].self, forKey: .scanDirectories)
        appIconStyle = (try? c.decodeIfPresent(AppIconStyle.self, forKey: .appIconStyle)) ?? .iconD
    }
}
