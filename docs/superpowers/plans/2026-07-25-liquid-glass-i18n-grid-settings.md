# Liquid Glass Folder, Russian i18n, Grid & Icon Settings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add macOS 26 Liquid Glass folder popup background with drag-over scale animation, Russian language support, and user-configurable grid layout (rows/cols), icon size (S/M/L), and app name visibility.

**Architecture:** Extend `UserPreferences` with new keys, make `GridMetrics` dynamic (reading from preferences), pass wallpaper image into `FolderPopupView` for blurred-glass backdrop, add Russian strings to `Localizer`, and expose new settings in `AppearanceSettingsView`.

**Tech Stack:** SwiftUI, AppKit (NSImage), macOS 14+ (with macOS 26 Liquid Glass via `#available`)

## Global Constraints

- Minimum deployment target: macOS 14.0
- Liquid Glass (`.glassEffect`) only on macOS 26+; fallback to translucent fill on earlier
- All new preferences must decode gracefully from older JSON (default values in `init(from:)`)
- Grid positions must be deterministic: app at index `i` → row `i / cols`, col `i % cols`
- Icon size changes must never shift grid cell positions or dimensions
- Russian translations must cover all ~40 existing keys plus new layout/icon keys

---

### Task 1: Add New Preference Keys

**Files:**
- Modify: `Sources/InceptLaunch/Models/UserPreferences.swift`

**Interfaces:**
- Produces: `UserPreferences.gridRows: Int` (0=auto, 4, 5, 6), `UserPreferences.gridColumns: Int` (6–10), `UserPreferences.iconSizeLevel: IconSizeLevel`, `UserPreferences.showAppNames: Bool`, `UserPreferences.Language.russian`

- [ ] **Step 1: Add `IconSizeLevel` enum and `Language.russian` case**

In `UserPreferences.swift`, add inside the struct (after `BackgroundMode` enum):

```swift
/// Icon rendering size within a grid cell. Does not affect cell dimensions.
enum IconSizeLevel: String, Codable, Equatable, CaseIterable {
    case small
    case medium
    case large

    var multiplier: CGFloat {
        switch self {
        case .small: return 0.65
        case .medium: return 0.80
        case .large: return 1.0
        }
    }
}
```

Add `.russian` to the `Language` enum:

```swift
enum Language: String, Codable, Equatable, CaseIterable {
    case system
    case chinese
    case english
    case japanese
    case korean
    case russian

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .chinese: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .russian: return "Русский"
        }
    }
}
```

- [ ] **Step 2: Add new stored properties**

After `showHiddenInSearch`, add:

```swift
var gridRows: Int = 0          // 0 = auto (screen-adaptive), 4/5/6 = fixed
var gridColumns: Int = 7       // 6, 7, 8, 9, 10
var iconSizeLevel: IconSizeLevel = .medium
var showAppNames: Bool = true
```

- [ ] **Step 3: Update `CodingKeys`**

Add to the `CodingKeys` enum:

```swift
case gridRows, gridColumns, iconSizeLevel, showAppNames
```

- [ ] **Step 4: Update memberwise `init`**

Add parameters with defaults to the existing `init(hotKey:...)`:

```swift
gridRows: Int = 0,
gridColumns: Int = 7,
iconSizeLevel: IconSizeLevel = .medium,
showAppNames: Bool = true
```

And assign them in the body.

- [ ] **Step 5: Update `init(from decoder:)`**

Add graceful decoding after `showHiddenInSearch`:

```swift
gridRows = (try? c.decodeIfPresent(Int.self, forKey: .gridRows)) ?? 0
gridColumns = (try? c.decodeIfPresent(Int.self, forKey: .gridColumns)) ?? 7
iconSizeLevel = (try? c.decodeIfPresent(IconSizeLevel.self, forKey: .iconSizeLevel)) ?? .medium
showAppNames = (try? c.decodeIfPresent(Bool.self, forKey: .showAppNames)) ?? true
```

- [ ] **Step 6: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds (or only unrelated warnings).

- [ ] **Step 7: Commit**

```bash
git add Sources/InceptLaunch/Models/UserPreferences.swift
git commit -m "feat: add gridRows, gridColumns, iconSizeLevel, showAppNames, russian language preferences"
```

---

### Task 2: Russian i18n + New Localization Keys

**Files:**
- Modify: `Sources/InceptLaunch/Support/Localizer.swift`

**Interfaces:**
- Consumes: `UserPreferences.Language.russian` (from Task 1)
- Produces: `Localizer.t()` resolving Russian keys; new keys for layout/icon settings in all 5 languages

- [ ] **Step 1: Add `.russian` to `AppLanguage` enum and resolution**

```swift
enum AppLanguage {
    case system, chinese, english, japanese, korean, russian

    static func from(_ lang: UserPreferences.Language) -> AppLanguage {
        switch lang {
        case .system: return .system
        case .chinese: return .chinese
        case .english: return .english
        case .japanese: return .japanese
        case .korean: return .korean
        case .russian: return .russian
        }
    }
}
```

In `t(_:)`, add to the `.system` switch:

```swift
case "ru": return ruStrings[key] ?? key
```

And add a case in the main switch:

```swift
case .russian: return ruStrings[key] ?? key
```

- [ ] **Step 2: Add new localization keys to all existing dictionaries**

Add these keys to `enStrings`, `zhStrings`, `jaStrings`, `koStrings`:

```swift
// Layout settings
"settings.layout": "Layout" / "布局" / "レイアウト" / "레이아웃"
"settings.gridRows": "Rows per page" / "每页行数" / "ページあたりの行数" / "페이지당 행 수"
"settings.gridRowsAuto": "Auto" / "自动" / "自動" / "자동"
"settings.gridColumns": "Columns per page" / "每页列数" / "ページあたりの列数" / "페이지당 열 수"
"settings.iconSize": "Icon size" / "图标大小" / "アイコンサイズ" / "아이콘 크기"
"settings.iconSizeSmall": "Small" / "小" / "小" / "작게"
"settings.iconSizeMedium": "Medium" / "中" / "中" / "중간"
"settings.iconSizeLarge": "Large" / "大" / "大" / "크게"
"settings.showAppNames": "Show app names" / "显示应用名称" / "アプリ名を表示" / "앱 이름 표시"
```

- [ ] **Step 3: Add `ruStrings` dictionary**

Add the full Russian dictionary with all existing ~40 keys plus the new layout keys:

```swift
// MARK: - Russian

static let ruStrings: [String: String] = [
    // Settings sections
    "settings.launch": "Запуск",
    "settings.appearance": "Внешний вид",
    "settings.apps": "Приложения",
    "settings.background": "Фон",
    "settings.hiddenApps": "Скрытые приложения",
    "settings.animations": "Анимации",
    "settings.language": "Язык интерфейса",
    "settings.languagePicker": "Настройки языка",

    // Launch settings
    "settings.hotKey": "Глобальное сочетание клавиш",
    "settings.launchAtLogin": "Запускать при входе",
    "settings.showMenuBarIcon": "Показывать значок в строке меню",
    "settings.showDockIcon": "Показывать значок в Dock",

    // Appearance settings
    "settings.backgroundBlur": "Размытие фона",
    "settings.reduceMotion": "Уменьшить движение",
    "settings.appIcon": "Значок приложения",

    // Background settings
    "settings.showDesktop": "Показывать фон рабочего стола",
    "settings.uploadBackground": "Загрузить фоновое изображение",
    "settings.backgroundMode": "Режим фона",
    "settings.autoCarousel": "Автоматическая карусель фона",
    "settings.carouselHint": "Фоновые изображения меняются при каждом перелистывании",
    "settings.firstImageHint": "Первое загруженное изображение используется как фон",
    "settings.resetBackground": "Сбросить фон",
    "settings.noHiddenApps": "Нет скрытых приложений",

    // Animation settings
    "settings.animateIcons": "Анимация значков",
    "settings.animatePageFlip": "Анимация перелистывания",
    "settings.animateFolder": "Анимация папок",
    "settings.animateDrag": "Анимация перетаскивания",
    "settings.animateSearch": "Анимация поиска",

    // Apps settings
    "settings.showSystemApps": "Показывать системные приложения",

    // Settings navigation
    "settings.general": "Основные",
    "settings.interface": "Интерфейс",
    "settings.appManagement": "Управление приложениями",
    "settings.about": "О программе",
    "settings.systemApps": "Системные приложения",
    "settings.showHiddenInSearch": "Показывать скрытые в поиске",
    "settings.title": "Настройки InceptLaunch",

    // About
    "about.version": "Версия",
    "about.website": "Веб-сайт",
    "about.wechatOA": "WeChat OA",
    "about.copied": "Скопировано",

    // Context menu
    "menu.trash": "Переместить в корзину",
    "menu.hide": "Скрыть",
    "menu.unhide": "Показать",
    "menu.enlargeFolder": "Увеличить папку",
    "menu.shrinkFolder": "Уменьшить папку",
    "menu.tidyGrid": "Упорядочить",
    "menu.resetBackground": "Сбросить фон",
    "menu.editModeHint": "Нажмите для выхода из режима редактирования",

    // Settings actions
    "settings.upload": "Загрузить",
    "settings.chooseImage": "Выбрать изображение",

    // Menu bar
    "menubar.open": "Открыть InceptLaunch",
    "menubar.settings": "Настройки…",
    "menubar.logs": "Открыть файл журнала",
    "menubar.quit": "Выйти",

    // Search
    "search.placeholder": "Поиск",

    // Accessibility
    "accessibility.prompt": "InceptLaunch требует разрешения на универсальный доступ для использования глобальных сочетаний клавиш. Включите его в Системные настройки > Конфиденциальность и безопасность > Универсальный доступ.",

    // Layout settings
    "settings.layout": "Раскладка",
    "settings.gridRows": "Строк на странице",
    "settings.gridRowsAuto": "Авто",
    "settings.gridColumns": "Столбцов на странице",
    "settings.iconSize": "Размер значков",
    "settings.iconSizeSmall": "Маленький",
    "settings.iconSizeMedium": "Средний",
    "settings.iconSizeLarge": "Большой",
    "settings.showAppNames": "Показывать названия приложений",
]
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Support/Localizer.swift
git commit -m "feat: add Russian i18n and layout/icon localization keys"
```

---

### Task 3: Dynamic Grid Layout from Preferences

**Files:**
- Modify: `Sources/InceptLaunch/Support/GridMetrics.swift`
- Modify: `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift:83-85`
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridView.swift:46-48`
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridLayout.swift`

**Interfaces:**
- Consumes: `UserPreferences.gridRows`, `UserPreferences.gridColumns` (from Task 1)
- Produces: `GridMetrics.effectiveRows(preference:screenHeight:)`, `GridMetrics.effectiveColumns(preference:)`; `LaunchpadGridView` passes dynamic columns to `LaunchpadGridLayout`

- [ ] **Step 1: Add dynamic methods to `GridMetrics`**

In `GridMetrics.swift`, add:

```swift
/// Returns the user-configured row count, or auto-calculates from screen height.
static func effectiveRows(preference: Int, screenHeight: CGFloat) -> Int {
    if preference >= 4 && preference <= 6 {
        return preference
    }
    return rows(forScreenHeight: screenHeight)
}

/// Returns the user-configured column count (clamped to valid range).
static func effectiveColumns(preference: Int) -> Int {
    min(max(preference, 6), 10)
}

/// Computes cell dimensions for a fixed rows×cols grid within the given area.
static func cellSize(rows: Int, columns: Int, availableWidth: CGFloat, availableHeight: CGFloat) -> (width: CGFloat, height: CGFloat) {
    let cellWidth = (availableWidth - CGFloat(columns - 1) * columnSpacing) / CGFloat(columns)
    let cellHeight = (availableHeight - CGFloat(rows - 1) * rowSpacing) / CGFloat(rows)
    return (max(cellWidth, 60), max(cellHeight, 60))
}
```

- [ ] **Step 2: Update `LaunchpadViewModel.gridRows`**

Replace the computed property at line 83–85:

```swift
var gridRows: Int {
    GridMetrics.effectiveRows(preference: preferences.gridRows, screenHeight: screenHeight)
}

var gridColumns: Int {
    GridMetrics.effectiveColumns(preference: preferences.gridColumns)
}
```

Note: The ViewModel already has a `preferences` property (loaded from `PreferencesStore`). Verify it exists; if not, add `var preferences: UserPreferences` loaded in `init`.

- [ ] **Step 3: Update `LaunchpadGridView` to use dynamic columns**

In `LaunchpadGridView`, add a `columns` property:

```swift
let columns: Int
```

Update the `GeometryReader` computation (lines 46–48) to use dynamic cell sizing:

```swift
let effectiveRows = rows
let effectiveCols = columns
let gridAreaWidth = geo.size.width - 48  // 24pt horizontal padding each side
let gridAreaHeight = geo.size.height
let cell = GridMetrics.cellSize(rows: effectiveRows, columns: effectiveCols, availableWidth: gridAreaWidth, availableHeight: gridAreaHeight)
let tileWidth = cell.width
let tileHeight = min(cell.height, GridMetrics.tileHeight)
let iconSize = GridMetrics.iconSize * (tileHeight / GridMetrics.tileHeight)
```

Pass `columns: columns` and `tileWidth: tileWidth` to `LaunchpadGridLayout` in `pageGrid`:

```swift
LaunchpadGridLayout(
    columns: columns,
    tileWidth: tileWidth,
    tileHeight: tileHeight,
    minRows: rows
)
```

- [ ] **Step 4: Update `ContentView` to pass `columns`**

In `ContentView.swift`, where `LaunchpadGridView` is instantiated (~line 193), add:

```swift
columns: viewModel.gridColumns,
```

- [ ] **Step 5: Update `pageCapacity` usage**

In `LaunchpadViewModel`, replace all `GridMetrics.pageCapacity(rows: gridRows)` calls with:

```swift
gridColumns * gridRows
```

- [ ] **Step 6: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Sources/InceptLaunch/Support/GridMetrics.swift Sources/InceptLaunch/Stores/LaunchpadViewModel.swift Sources/InceptLaunch/Views/LaunchpadGridView.swift Sources/InceptLaunch/Views/ContentView.swift
git commit -m "feat: dynamic grid rows/columns from user preferences"
```

---

### Task 4: Icon Size Adaptive + Show App Names

**Files:**
- Modify: `Sources/InceptLaunch/Views/AppIconView.swift`
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridView.swift`

**Interfaces:**
- Consumes: `UserPreferences.IconSizeLevel.multiplier`, `UserPreferences.showAppNames` (from Task 1)
- Produces: `AppIconView` renders icon at `iconSize * multiplier` within the same cell frame; label conditionally hidden

- [ ] **Step 1: Add `iconScale` and `showName` parameters to `AppIconView`**

In `AppIconView.swift`, add properties:

```swift
var iconScale: CGFloat = 1.0
var showName: Bool = true
```

Update the body:

```swift
var body: some View {
    VStack(spacing: showName ? 10 : 0) {
        iconView
            .frame(width: iconSize * iconScale, height: iconSize * iconScale)
            .overlay(alignment: .bottomTrailing) {
                if showHiddenBadge {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Circle().fill(.black.opacity(0.55)))
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: iconSize, height: iconSize)  // occupy full slot regardless of scale
        if showName {
            Text(item.title)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
    }
    .frame(width: 132, height: tileHeight)
    .contentShape(Rectangle())
}
```

- [ ] **Step 2: Pass `iconScale` and `showName` from `LaunchpadGridView`**

Add properties to `LaunchpadGridView`:

```swift
var iconSizeLevel: UserPreferences.IconSizeLevel = .medium
var showAppNames: Bool = true
```

In `tileView(item:iconSize:tileHeight:enlarged:)`, pass through:

```swift
AppIconView(
    item: item,
    iconSize: iconSize,
    tileHeight: tileHeight,
    iconScale: iconSizeLevel.multiplier,
    showName: showAppNames
)
```

- [ ] **Step 3: Pass from `ContentView`**

In `ContentView.swift`, where `LaunchpadGridView` is instantiated, add:

```swift
iconSizeLevel: preferences.iconSizeLevel,
showAppNames: preferences.showAppNames,
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Views/AppIconView.swift Sources/InceptLaunch/Views/LaunchpadGridView.swift Sources/InceptLaunch/Views/ContentView.swift
git commit -m "feat: icon size adaptive (S/M/L) and show/hide app names toggle"
```

---

### Task 5: Settings UI — Layout & Icon Sections

**Files:**
- Modify: `Sources/InceptLaunch/Views/SettingsView.swift:127-187`

**Interfaces:**
- Consumes: `UserPreferences.gridRows`, `.gridColumns`, `.iconSizeLevel`, `.showAppNames` (from Task 1); localization keys (from Task 2)
- Produces: Settings > Interface shows Layout and Icons sections with pickers/toggles

- [ ] **Step 1: Add Layout section to `AppearanceSettingsView`**

After the existing "Appearance" section (after the icon style picker `VStack`), add:

```swift
Section(Localizer.t("settings.layout")) {
    Picker(Localizer.t("settings.gridRows"), selection: $preferences.gridRows) {
        Text(Localizer.t("settings.gridRowsAuto")).tag(0)
        Text("4").tag(4)
        Text("5").tag(5)
        Text("6").tag(6)
    }
    .pickerStyle(.segmented)

    Picker(Localizer.t("settings.gridColumns"), selection: $preferences.gridColumns) {
        Text("6").tag(6)
        Text("7").tag(7)
        Text("8").tag(8)
        Text("9").tag(9)
        Text("10").tag(10)
    }
    .pickerStyle(.segmented)
}
```

- [ ] **Step 2: Add Icons section**

After the Layout section:

```swift
Section(Localizer.t("settings.iconSize")) {
    Picker(Localizer.t("settings.iconSize"), selection: $preferences.iconSizeLevel) {
        Text(Localizer.t("settings.iconSizeSmall")).tag(UserPreferences.IconSizeLevel.small)
        Text(Localizer.t("settings.iconSizeMedium")).tag(UserPreferences.IconSizeLevel.medium)
        Text(Localizer.t("settings.iconSizeLarge")).tag(UserPreferences.IconSizeLevel.large)
    }
    .pickerStyle(.segmented)

    Toggle(Localizer.t("settings.showAppNames"), isOn: $preferences.showAppNames)
}
```

- [ ] **Step 3: Add `onChange` handlers for new preferences**

After the existing `.onChange` modifiers in `AppearanceSettingsView`:

```swift
.onChange(of: preferences.gridRows) { _, _ in onSave() }
.onChange(of: preferences.gridColumns) { _, _ in onSave() }
.onChange(of: preferences.iconSizeLevel) { _, _ in onSave() }
.onChange(of: preferences.showAppNames) { _, _ in onSave() }
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Views/SettingsView.swift
git commit -m "feat: settings UI for grid layout, icon size, and app name visibility"
```

---

### Task 6: Folder Popup — Blurred Wallpaper Background

**Files:**
- Modify: `Sources/InceptLaunch/Views/FolderPopupView.swift:6-12,42-44`
- Modify: `Sources/InceptLaunch/Views/ContentView.swift:46-99`

**Interfaces:**
- Consumes: `DesktopWallpaperCapture.currentImage` (existing static), `UserPreferences.backgroundBlur`
- Produces: Folder popup shows blurred wallpaper behind the glass panel instead of flat black

- [ ] **Step 1: Add wallpaper parameters to `FolderPopupView`**

Add properties after `var animate: Bool = true`:

```swift
var wallpaperImage: NSImage? = nil
var backgroundBlur: Double = 0.72
```

- [ ] **Step 2: Replace the backdrop in `FolderPopupView.body`**

Replace lines 42–53 (the `Color.black.opacity(0.35)` block):

```swift
ZStack {
    // Blurred wallpaper backdrop matching the main grid aesthetic
    Group {
        if let wallpaperImage {
            Image(nsImage: wallpaperImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 40)
        } else {
            Color.black
        }
    }
    .ignoresSafeArea()
    .overlay(
        Color.black.opacity(backgroundBlur * 0.5)
            .ignoresSafeArea()
    )
    .contentShape(Rectangle())
    .onTapGesture {
        DiagLog.write("FolderPopup backdrop tap fired")
        if editMode {
            onCancelEditMode?()
        } else {
            onClose()
        }
    }
```

- [ ] **Step 3: Pass wallpaper from `ContentView`**

In `ContentView.swift`, where `FolderPopupView` is instantiated (~line 46), add parameters:

```swift
wallpaperImage: DesktopWallpaperCapture.currentImage,
backgroundBlur: preferences.backgroundBlur,
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Views/FolderPopupView.swift Sources/InceptLaunch/Views/ContentView.swift
git commit -m "feat: folder popup uses blurred wallpaper background (Liquid Glass aesthetic)"
```

---

### Task 7: Folder Drag-Over Scale Animation

**Files:**
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridView.swift:126-187`

**Interfaces:**
- Consumes: `animateDrag` preference, tile frame data from `TileFramePreferenceKey`
- Produces: Folder tiles scale to 1.08× when a dragged app enters their acceptance threshold

- [ ] **Step 1: Add folder-hover state to `LaunchpadGridView`**

Add a `@State` property:

```swift
@State private var hoveredFolderID: String? = nil
```

- [ ] **Step 2: Detect folder hover during drag**

In `directDragGesture`'s `.onChanged`, after the live-reorder block, add folder hover detection:

```swift
// Folder scale-up feedback: check if pointer is over a folder tile
let folderTarget = tileFrames.first { info in
    info.isFolder
    && info.id != item.id
    && info.frame.insetBy(dx: -10, dy: -10).contains(value.location)
}
let newHover = folderTarget?.id
if newHover != hoveredFolderID {
    withAnimation(animateDrag ? .spring(response: 0.25, dampingFraction: 0.7) : nil) {
        hoveredFolderID = newHover
    }
}
```

In `.onEnded`, clear the hover:

```swift
withAnimation(animateDrag ? .spring(response: 0.25, dampingFraction: 0.7) : nil) {
    hoveredFolderID = nil
}
```

- [ ] **Step 3: Apply scale to folder tiles**

In `tileCell`, after the existing `.scaleEffect(isBeingDragged ? 1.1 : 1.0)` line, modify to include folder hover:

```swift
.scaleEffect(isBeingDragged ? 1.1 : (isFolder && hoveredFolderID == item.id ? 1.08 : 1.0))
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Views/LaunchpadGridView.swift
git commit -m "feat: folder tiles scale up when dragged app enters acceptance threshold"
```

---

### Task 8: Integration Build & Visual Verification

**Files:**
- None (verification only)

- [ ] **Step 1: Full clean build**

Run: `swift build 2>&1 | tail -10`
Expected: Build succeeds with no errors.

- [ ] **Step 2: Run tests**

Run: `swift test 2>&1 | tail -20`
Expected: All existing tests pass.

- [ ] **Step 3: Build and run the app for visual verification**

Run: `./script/build_and_run.sh run`

Verify manually:
1. Open grid → check grid uses 7 columns (default) with correct spacing
2. Open Settings > Interface → change rows to 5, columns to 8 → grid updates
3. Change icon size to Small → icons shrink within cells, positions unchanged
4. Toggle "Show app names" off → labels disappear, cells compact
5. Open a folder → blurred wallpaper background visible behind glass panel
6. Drag an app over a folder → folder scales up slightly
7. Switch language to Русский → all UI text in Russian

- [ ] **Step 4: Final commit (if any fixups needed)**

```bash
git add -A
git commit -m "fix: integration fixups for grid settings and folder glass"
```
