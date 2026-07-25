import Foundation

extension Notification.Name {
    static let inceptLaunchLanguageChanged = Notification.Name("inceptLaunchLanguageChanged")
}

enum AppLanguage {
    case system, chinese, english, japanese, korean

    static func from(_ lang: UserPreferences.Language) -> AppLanguage {
        switch lang {
        case .system: return .system
        case .chinese: return .chinese
        case .english: return .english
        case .japanese: return .japanese
        case .korean: return .korean
        }
    }
}

@MainActor
struct Localizer {
    static var current: AppLanguage = .system

    static func setLanguage(_ lang: UserPreferences.Language) {
        let newLang = AppLanguage.from(lang)
        guard newLang != current else { return }
        current = newLang
        NotificationCenter.default.post(name: .inceptLaunchLanguageChanged, object: nil)
    }

    static func t(_ key: String) -> String {
        let lang = current
        if lang == .system {
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            switch code {
            case "zh": return zhStrings[key] ?? key
            case "ja": return jaStrings[key] ?? key
            case "ko": return koStrings[key] ?? key
            default: return enStrings[key] ?? key
            }
        }
        switch lang {
        case .chinese: return zhStrings[key] ?? key
        case .english: return enStrings[key] ?? key
        case .japanese: return jaStrings[key] ?? key
        case .korean: return koStrings[key] ?? key
        case .system: return key
        }
    }

    // MARK: - English

    static let enStrings: [String: String] = [
        // Settings sections
        "settings.launch": "Launch",
        "settings.appearance": "Appearance",
        "settings.apps": "Apps",
        "settings.background": "Background",
        "settings.hiddenApps": "Hidden Apps",
        "settings.animations": "Animations",
        "settings.language": "Interface Language",
        "settings.languagePicker": "Language Settings",

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
        "settings.title": "InceptLaunch Settings",

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
        "menubar.logs": "Open Log File",
        "menubar.quit": "Quit",

        // Accessibility
        "accessibility.prompt": "InceptLaunch needs Accessibility permission to use global shortcuts. Please enable it in System Settings > Privacy & Security > Accessibility.",
    ]

    // MARK: - Chinese (Simplified)

    static let zhStrings: [String: String] = [
        // Settings sections
        "settings.launch": "启动",
        "settings.appearance": "外观",
        "settings.apps": "应用",
        "settings.background": "背景",
        "settings.hiddenApps": "隐藏应用",
        "settings.animations": "动画",
        "settings.language": "界面语言",
        "settings.languagePicker": "语言设置",

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
        "settings.title": "InceptLaunch 设置",

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
        "menubar.logs": "打开日志文件",
        "menubar.quit": "退出",

        // Accessibility
        "accessibility.prompt": "InceptLaunch 需要辅助功能权限才能使用全局快捷键。请在系统设置 > 隐私与安全性 > 辅助功能中启用。",
    ]

    // MARK: - Japanese

    static let jaStrings: [String: String] = [
        // Settings sections
        "settings.launch": "起動",
        "settings.appearance": "外観",
        "settings.apps": "アプリ",
        "settings.background": "背景",
        "settings.hiddenApps": "非表示のアプリ",
        "settings.animations": "アニメーション",
        "settings.language": "表示言語",
        "settings.languagePicker": "言語設定",

        // Launch settings
        "settings.hotKey": "グローバルショートカット",
        "settings.launchAtLogin": "ログイン時に起動",
        "settings.showMenuBarIcon": "メニューバーアイコンを表示",
        "settings.showDockIcon": "Dockアイコンを表示",

        // Appearance settings
        "settings.backgroundBlur": "背景のぼかし",
        "settings.reduceMotion": "視差効果を減らす",
        "settings.appIcon": "アプリアイコン",

        // Background settings
        "settings.showDesktop": "デスクトップ背景を表示",
        "settings.uploadBackground": "背景画像をアップロード",
        "settings.autoCarousel": "背景の自動カルーセル",
        "settings.carouselHint": "ページをめくるたびに背景画像が切り替わります",
        "settings.firstImageHint": "最初のアップロード画像を背景として使用",
        "settings.resetBackground": "背景をリセット",
        "settings.noHiddenApps": "非表示のアプリはありません",

        // Animation settings
        "settings.animateIcons": "アイコンアニメーション",
        "settings.animatePageFlip": "ページめくりアニメーション",
        "settings.animateFolder": "フォルダアニメーション",
        "settings.animateDrag": "ドラッグアニメーション",
        "settings.animateSearch": "検索トランジション",

        // Apps settings
        "settings.showSystemApps": "システムアプリケーションを表示",

        // Settings navigation
        "settings.general": "一般",
        "settings.interface": "インターフェース",
        "settings.appManagement": "アプリ管理",
        "settings.about": "について",
        "settings.systemApps": "システムアプリケーション",
        "settings.showHiddenInSearch": "検索で非表示アプリを表示",
        "settings.title": "InceptLaunch 設定",

        // About
        "about.version": "バージョン",
        "about.website": "ウェブサイト",
        "about.wechatOA": "WeChat公式アカウント",
        "about.copied": "コピーしました",

        // Context menu
        "menu.trash": "ゴミ箱に移動",
        "menu.hide": "非表示",
        "menu.unhide": "表示",
        "menu.enlargeFolder": "フォルダを拡大",
        "menu.shrinkFolder": "フォルダを縮小",
        "menu.tidyGrid": "整理",
        "menu.resetBackground": "背景をリセット",
        "menu.editModeHint": "タップして編集モードを終了",

        // Settings actions
        "settings.upload": "アップロード",
        "settings.chooseImage": "画像を選択",

        // Menu bar
        "menubar.open": "InceptLaunchを開く",
        "menubar.settings": "設定…",
        "menubar.logs": "ログファイルを開く",
        "menubar.quit": "終了",

        // Accessibility
        "accessibility.prompt": "InceptLaunchはグローバルショートカットを使用するためにアクセシビリティ権限が必要です。システム設定 > プライバシーとセキュリティ > アクセシビリティで有効にしてください。",
    ]

    // MARK: - Korean

    static let koStrings: [String: String] = [
        // Settings sections
        "settings.launch": "실행",
        "settings.appearance": "외관",
        "settings.apps": "앱",
        "settings.background": "배경",
        "settings.hiddenApps": "숨긴 앱",
        "settings.animations": "애니메이션",
        "settings.language": "인터페이스 언어",
        "settings.languagePicker": "언어 설정",

        // Launch settings
        "settings.hotKey": "글로벌 단축키",
        "settings.launchAtLogin": "로그인 시 실행",
        "settings.showMenuBarIcon": "메뉴 막대 아이콘 표시",
        "settings.showDockIcon": "Dock 아이콘 표시",

        // Appearance settings
        "settings.backgroundBlur": "배경 흐림",
        "settings.reduceMotion": "동작 줄이기",
        "settings.appIcon": "앱 아이콘",

        // Background settings
        "settings.showDesktop": "데스크탑 배경 표시",
        "settings.uploadBackground": "배경 이미지 업로드",
        "settings.autoCarousel": "배경 자동 캐러셀",
        "settings.carouselHint": "페이지를 넘길 때마다 배경 이미지가 전환됩니다",
        "settings.firstImageHint": "첫 번째 업로드 이미지를 배경으로 사용",
        "settings.resetBackground": "배경 재설정",
        "settings.noHiddenApps": "숨긴 앱이 없습니다",

        // Animation settings
        "settings.animateIcons": "아이콘 애니메이션",
        "settings.animatePageFlip": "페이지 넘김 애니메이션",
        "settings.animateFolder": "폴더 애니메이션",
        "settings.animateDrag": "드래그 애니메이션",
        "settings.animateSearch": "검색 전환",

        // Apps settings
        "settings.showSystemApps": "시스템 응용 프로그램 표시",

        // Settings navigation
        "settings.general": "일반",
        "settings.interface": "인터페이스",
        "settings.appManagement": "앱 관리",
        "settings.about": "정보",
        "settings.systemApps": "시스템 응용 프로그램",
        "settings.showHiddenInSearch": "검색에서 숨긴 앱 표시",
        "settings.title": "InceptLaunch 설정",

        // About
        "about.version": "버전",
        "about.website": "웹사이트",
        "about.wechatOA": "WeChat 공식 계정",
        "about.copied": "복사됨",

        // Context menu
        "menu.trash": "휴지통으로 이동",
        "menu.hide": "숨기기",
        "menu.unhide": "표시",
        "menu.enlargeFolder": "폴더 확대",
        "menu.shrinkFolder": "폴더 축소",
        "menu.tidyGrid": "정리",
        "menu.resetBackground": "배경 재설정",
        "menu.editModeHint": "탭하여 편집 모드 종료",

        // Settings actions
        "settings.upload": "업로드",
        "settings.chooseImage": "이미지 선택",

        // Menu bar
        "menubar.open": "InceptLaunch 열기",
        "menubar.settings": "설정…",
        "menubar.logs": "로그 파일 열기",
        "menubar.quit": "종료",

        // Accessibility
        "accessibility.prompt": "InceptLaunch는 글로벌 단축키를 사용하려면 손쉬운 사용 권한이 필요합니다. 시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용에서 활성화해 주세요.",
    ]
}
