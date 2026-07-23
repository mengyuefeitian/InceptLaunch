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

        /// 128×128 PNG thumbnail for the settings icon picker.
        var thumbnailName: String {
            switch self {
            case .iconD: return "thumb_InceptLaunch-D"
            case .icon01: return "thumb_icon01"
            case .icon02: return "thumb_icon02"
            case .icon03: return "thumb_icon03"
            }
        }
    }

    /// Background display mode for the overlay.
    enum BackgroundMode: String, Codable, Equatable {
        case desktop  // Show desktop background (transparent overlay)
        case uploaded // Use uploaded background images
    }

    /// UI language preference.
    enum Language: String, Codable, Equatable, CaseIterable {
        case system  // Follow system language
        case chinese // Force Chinese
        case english // Force English

        var displayName: String {
            switch self {
            case .system: return "跟随系统"
            case .chinese: return "简体中文"
            case .english: return "English"
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

    // New fields for v1.3.0
    var language: Language = .system
    var backgroundMode: BackgroundMode = .desktop
    var backgroundImages: [String] = []  // File paths to uploaded background images
    var autoCarousel: Bool = false
    var animateIcons: Bool = true        // Icon fade-in / scale animation
    var animatePageFlip: Bool = true     // Page transition animation
    var animateFolder: Bool = true       // Folder expand/collapse animation
    var animateDrag: Bool = true         // Drag reposition animation
    var animateSearch: Bool = true       // Search results transition

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
        case language, backgroundMode, backgroundImages, autoCarousel
        case animateIcons, animatePageFlip, animateFolder, animateDrag, animateSearch
    }

    init(hotKey: String, launchAtLogin: Bool, showMenuBarIcon: Bool, showDockIcon: Bool, backgroundBlur: Double, reduceMotion: Bool, showSystemApplications: Bool, overlayDisplayMode: OverlayDisplayMode, scanDirectories: [String], appIconStyle: AppIconStyle = .iconD, language: Language = .system, backgroundMode: BackgroundMode = .desktop, backgroundImages: [String] = [], autoCarousel: Bool = false, animateIcons: Bool = true, animatePageFlip: Bool = true, animateFolder: Bool = true, animateDrag: Bool = true, animateSearch: Bool = true) {
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
        self.language = language
        self.backgroundMode = backgroundMode
        self.backgroundImages = backgroundImages
        self.autoCarousel = autoCarousel
        self.animateIcons = animateIcons
        self.animatePageFlip = animatePageFlip
        self.animateFolder = animateFolder
        self.animateDrag = animateDrag
        self.animateSearch = animateSearch
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
        language = (try? c.decodeIfPresent(Language.self, forKey: .language)) ?? .system
        backgroundMode = (try? c.decodeIfPresent(BackgroundMode.self, forKey: .backgroundMode)) ?? .desktop
        backgroundImages = (try? c.decodeIfPresent([String].self, forKey: .backgroundImages)) ?? []
        autoCarousel = (try? c.decodeIfPresent(Bool.self, forKey: .autoCarousel)) ?? false
        animateIcons = (try? c.decodeIfPresent(Bool.self, forKey: .animateIcons)) ?? true
        animatePageFlip = (try? c.decodeIfPresent(Bool.self, forKey: .animatePageFlip)) ?? true
        animateFolder = (try? c.decodeIfPresent(Bool.self, forKey: .animateFolder)) ?? true
        animateDrag = (try? c.decodeIfPresent(Bool.self, forKey: .animateDrag)) ?? true
        animateSearch = (try? c.decodeIfPresent(Bool.self, forKey: .animateSearch)) ?? true
    }
}
