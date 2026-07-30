# Design: Liquid Glass Folder, Russian i18n, Grid & Icon Settings

Date: 2026-07-25

## Feature 1: Folder Popup — Liquid Glass + Scale Animation

### Background

The folder popup currently uses a flat `Color.black.opacity(0.35)` backdrop that
doesn't match the main grid's blurred-wallpaper aesthetic or the macOS 26 Liquid
Glass visual language.

**Change:** Pass the already-captured desktop wallpaper image from `ContentView`
into `FolderPopupView`. Replace the black backdrop with:

1. Wallpaper image, scaled to fill, `.blur(radius: 40)`.
2. `Color.black.opacity(preferences.backgroundBlur * 0.5)` overlay (lighter than
   the main grid so the glass panel stands out).
3. The folder panel keeps `.liquidGlass(cornerRadius: 32, fallbackOpacity: 0.22)`.

On macOS 26+ this renders native Liquid Glass via `.glassEffect(.regular)`.
On earlier systems the fallback translucent-white fill applies.

### Scale Animation on Drag-Over

When a dragged tile enters a folder's acceptance threshold:

- Animate the folder tile to `scaleEffect(1.08)` with
  `.spring(response: 0.25, dampingFraction: 0.7)`.
- On exit or drop, animate back to `1.0`.
- Respects the existing `animateDrag` preference — if disabled, no scale.

### Files Affected

- `Sources/iLaunch/Views/FolderPopupView.swift` — accept wallpaper image
  param, replace backdrop.
- `Sources/iLaunch/Views/ContentView.swift` — pass wallpaper image down.
- `Sources/iLaunch/Views/LaunchpadGridView.swift` — folder scale animation
  state.

---

## Feature 2: Russian i18n

### Changes

- Add `.russian` case to `AppLanguage` enum (raw value `"ru"`).
- Add `ruStrings: [String: String]` dictionary with all ~40 keys translated to
  Russian.
- Register in `Localizer.t(_:)` resolution chain.
- Add to `SettingsView` language picker with display name `"Русский"`.
- Add to `UserPreferences.Language` enum if separate from `AppLanguage`.

### Files Affected

- `Sources/iLaunch/Support/Localizer.swift`
- `Sources/iLaunch/Models/UserPreferences.swift`
- `Sources/iLaunch/Views/SettingsView.swift`

---

## Feature 3: Settings > Interface Additions

### New Preferences

| Key | Type | Default | Options |
|-----|------|---------|---------|
| `gridRows` | Int | 0 (auto) | 0, 4, 5, 6 |
| `gridColumns` | Int | 7 | 6, 7, 8, 9, 10 |
| `iconSizeLevel` | enum | `.medium` | `.small`, `.medium`, `.large` |
| `showAppNames` | Bool | `true` | on/off |

### Grid Layout Behavior

- `gridRows == 0`: existing auto-calculation from screen height (unchanged).
- `gridRows` is 4/5/6: fixed row count.
  - Grid area height = screen height − `chromeHeight` (search bar + page dots).
  - Cell height = `(gridAreaHeight - (rows-1) * rowSpacing) / rows`.
  - Cell width = `(gridAreaWidth - (cols-1) * colSpacing) / cols`.
  - Positions are deterministic: app at index `i` → row `i / cols`, col `i % cols`.
- `gridColumns` replaces the hardcoded `7` in `GridMetrics` and
  `LaunchpadGridLayout`.

### Icon Size Adaptive

Cell size is determined solely by rows/cols. Icon size is a multiplier within
the cell:

| Level | Multiplier |
|-------|-----------|
| Small | 0.65 × cellIconSlot |
| Medium | 0.80 × cellIconSlot |
| Large | 1.0 × cellIconSlot |

Where `cellIconSlot = min(cellWidth, cellHeight) * 0.75`.

Changing icon size never shifts grid positions or cell dimensions.

### Show App Names

- When `showAppNames == false`: the `Text(appName)` below each icon is removed
  and the label height is collapsed (cell height recalculated without label
  area).
- When `true` (default): current behavior, label shown below icon.

### Settings UI (in AppearanceSettingsView)

New "布局" (Layout) section:

- Rows: segmented picker — 自动 / 4 / 5 / 6
- Columns: segmented picker — 6 / 7 / 8 / 9 / 10

New "图标" (Icons) section:

- Icon size: segmented picker — 小 / 中 / 大
- Show app names: Toggle (default on)

### Files Affected

- `Sources/iLaunch/Models/UserPreferences.swift` — new keys + enum.
- `Sources/iLaunch/Support/GridMetrics.swift` — dynamic rows/cols/iconSize.
- `Sources/iLaunch/Views/LaunchpadGridLayout.swift` — accept cols param,
  compute cell sizes from available space.
- `Sources/iLaunch/Views/LaunchpadGridView.swift` — pass dynamic metrics.
- `Sources/iLaunch/Views/ContentView.swift` — pass preferences to grid.
- `Sources/iLaunch/Views/SettingsView.swift` — new UI sections.
- `Sources/iLaunch/Support/Localizer.swift` — new keys for layout/icons
  labels in all languages (zh, en, ja, ko, ru).

---

## Testing Strategy

- Unit tests for `GridMetrics` with various rows/cols/iconSize combinations.
- Unit test for `Localizer.t()` resolving Russian keys.
- Visual verification: build and run, check folder popup glass effect, drag-over
  scale, grid layout with different row/col settings, icon size changes, and
  name toggle.
