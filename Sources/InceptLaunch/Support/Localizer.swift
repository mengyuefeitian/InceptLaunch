import Foundation

enum AppLanguage {
    case system, chinese, english
    
    static func from(_ lang: UserPreferences.Language) -> AppLanguage {
        switch lang {
        case .system: return .system
        case .chinese: return .chinese
        case .english: return .english
        }
    }
}

@MainActor
struct Localizer {
    static var current: AppLanguage = .system
    
    static func setLanguage(_ lang: UserPreferences.Language) {
        current = AppLanguage.from(lang)
    }
    
    static func t(_ key: String) -> String {
        let lang = current
        if lang == .system {
            // Use system locale
            let locale = Locale.current
            if locale.language.languageCode?.identifier == "zh" {
                return zhStrings[key] ?? key
            }
            return enStrings[key] ?? key
        }
        switch lang {
        case .chinese: return zhStrings[key] ?? key
        case .english: return enStrings[key] ?? key
        case .system: return key
        }
    }
    
    static let enStrings: [String: String] = [
        // Settings sections
        "settings.launch": "Launch",
        "settings.appearance": "Appearance",
        "settings.apps": "Apps",
        "settings.background": "Background",
        "settings.hiddenApps": "Hidden Apps",
        "settings.animations": "Animations",
        "settings.language": "Language",
        
        // Launch settings
        "settings.hotKey": "Global shortcut",
        "settings.launchAtLogin": "Launch at login",
        "settings.showMenuBarIcon": "Show menu bar icon",
        "settings.showDockIcon": "Show Dock icon",
        
        // Appearance settings
        "settings.backgroundBlur": "Background blur",
        "settings.reduceMotion": "Reduce motion",
        "settings.appIcon": "App icon",
        
        // Background settings
        "settings.showDesktop": "Show desktop background",
        "settings.uploadBackground": "Upload background image",
        "settings.autoCarousel": "Auto carousel backgrounds",
        "settings.carouselHint": "Background images rotate on each page flip",
        "settings.firstImageHint": "Using the first uploaded image as background",
        "settings.resetBackground": "Reset background",
        "settings.noHiddenApps": "No hidden apps",
        
        // Animation settings
        "settings.animateIcons": "Icon animations",
        "settings.animatePageFlip": "Page flip animation",
        "settings.animateFolder": "Folder animation",
        "settings.animateDrag": "Drag animation",
        "settings.animateSearch": "Search transition",
        
        // Apps settings
        "settings.showSystemApps": "Show system applications",

        // Settings navigation
        "settings.general": "General",
        "settings.interface": "Interface",
        "settings.appManagement": "App Management",
        "settings.about": "About",
        "settings.systemApps": "System Applications",
        "settings.showHiddenInSearch": "Show hidden apps in search",

        // About
        "about.version": "Version",
        "about.website": "Website",
        "about.wechatOA": "WeChat OA",
        "about.copied": "Copied",

        // Context menu
        "menu.trash": "Move to Trash",
        "menu.hide": "Hide",
        "menu.unhide": "Show",
        "menu.enlargeFolder": "Enlarge folder",
        "menu.shrinkFolder": "Shrink folder",
        "menu.tidyGrid": "Tidy up",
        "menu.resetBackground": "Reset background",
        "menu.editModeHint": "Tap to exit edit mode",
        
        // Settings actions
        "settings.upload": "Upload",
        "settings.chooseImage": "Choose image",
        
        // Menu bar
        "menubar.open": "Open InceptLaunch",
        "menubar.settings": "Settings…",
        "menubar.quit": "Quit",
        
        // Accessibility
        "accessibility.prompt": "InceptLaunch needs Accessibility permission to use global shortcuts. Please enable it in System Settings > Privacy & Security > Accessibility.",
    ]
    
    static let zhStrings: [String: String] = [
        // Settings sections
        "settings.launch": "启动",
        "settings.appearance": "外观",
        "settings.apps": "应用",
        "settings.background": "背景",
        "settings.hiddenApps": "隐藏应用",
        "settings.animations": "动画",
        "settings.language": "语言",
        
        // Launch settings
        "settings.hotKey": "全局快捷键",
        "settings.launchAtLogin": "开机自启",
        "settings.showMenuBarIcon": "显示菜单栏图标",
        "settings.showDockIcon": "显示 Dock 图标",
        
        // Appearance settings
        "settings.backgroundBlur": "背景模糊",
        "settings.reduceMotion": "减弱动态效果",
        "settings.appIcon": "应用图标",
        
        // Background settings
        "settings.showDesktop": "显示桌面背景",
        "settings.uploadBackground": "上传背景图",
        "settings.autoCarousel": "自动轮播背景图",
        "settings.carouselHint": "每次翻页自动切换背景图",
        "settings.firstImageHint": "默认以第一张图片为背景",
        "settings.resetBackground": "重置背景图",
        "settings.noHiddenApps": "暂无隐藏应用",
        
        // Animation settings
        "settings.animateIcons": "图标动画",
        "settings.animatePageFlip": "翻页动画",
        "settings.animateFolder": "文件夹动画",
        "settings.animateDrag": "拖拽动画",
        "settings.animateSearch": "搜索过渡动画",
        
        // Apps settings
        "settings.showSystemApps": "显示系统应用",

        // Settings navigation
        "settings.general": "通用",
        "settings.interface": "界面",
        "settings.appManagement": "应用管理",
        "settings.about": "关于",
        "settings.systemApps": "系统应用",
        "settings.showHiddenInSearch": "在搜索中显示隐藏应用",

        // About
        "about.version": "版本",
        "about.website": "官网",
        "about.wechatOA": "公众号",
        "about.copied": "已复制",

        // Context menu
        "menu.trash": "移到废纸篓",
        "menu.hide": "隐藏",
        "menu.unhide": "显示",
        "menu.enlargeFolder": "放大文件夹",
        "menu.shrinkFolder": "缩小文件夹",
        "menu.tidyGrid": "整理桌面",
        "menu.resetBackground": "重置背景图",
        "menu.editModeHint": "点击退出编辑模式",
        
        // Settings actions
        "settings.upload": "上传",
        "settings.chooseImage": "选择背景图",
        
        // Menu bar
        "menubar.open": "打开 InceptLaunch",
        "menubar.settings": "设置…",
        "menubar.quit": "退出",
        
        // Accessibility
        "accessibility.prompt": "InceptLaunch 需要辅助功能权限才能使用全局快捷键。请在系统设置 > 隐私与安全性 > 辅助功能中启用。",
    ]
}
