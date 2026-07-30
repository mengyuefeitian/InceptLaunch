# Settings Restructure & Feature Enhancements

Date: 2026-07-25

## Overview

Four changes to iLaunch v1.3.20:
1. Settings UI restructure with sidebar navigation
2. Fix system app toggle not refreshing the grid
3. Drag-to-reorder apps inside folder popups
4. Show hidden apps in search (with toggle + eye badge)

---

## 1. Settings UI Restructure

### Navigation

Replace the single-page grouped Form with a `NavigationSplitView`:

- **Sidebar** (left): `List` with 4 items bound to a `@State selection`:
  - 通用 (`gearshape`)
  - 界面 (`paintbrush`)
  - 应用管理 (`square.grid.2x2`)
  - 关于 (`info.circle`)
- **Detail** (right): switches content based on selection.
- Window size: ~700x520 (up from 560x520).

### Sub-views

| View | Contents |
|------|----------|
| `GeneralSettingsView` | 语言 picker, 动画 toggles (5), 启动 section (hotkey, launch-at-login, menu bar icon, dock icon) |
| `AppearanceSettingsView` | 外观 (blur slider, icon style picker), 背景 (mode picker, image grid, carousel toggle) |
| `AppManagementSettingsView` | 系统应用 toggle (renamed from 「应用」), 隐藏应用 list with unhide buttons, 搜索中显示隐藏应用 toggle (new) |
| `AboutView` | App icon (dynamic, follows `appIconStyle`), version string (from Bundle), links: 官网 (opens browser), X @countquery (opens browser), 公众号 mowenfeigong (copyable text) |

### About page details

- App icon: rendered from the current `appIconStyle` resource (same logic as `IconThumbnailView` but larger, ~96pt).
- Version: `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` or fallback from Package metadata.
- Links are tappable:
  - 官网: `https://www.xiaoanhome.xyz/` → `NSWorkspace.shared.open(url)`
  - X: `https://x.com/countquery` → `NSWorkspace.shared.open(url)`
  - 公众号: `mowenfeigong` → copy to pasteboard on click, show brief "已复制" feedback.

### Localization

New keys:
- `settings.general` → 通用 / General
- `settings.interface` → 界面 / Interface
- `settings.appManagement` → 应用管理 / App Management
- `settings.about` → 关于 / About
- `settings.systemApps` → 系统应用 / System Applications (replaces `settings.apps`)
- `settings.showHiddenInSearch` → 在搜索中显示隐藏应用 / Show hidden apps in search
- `about.website` → 官网 / Website
- `about.version` → 版本 / Version
- `about.copied` → 已复制 / Copied

---

## 2. System App Toggle Bug Fix

### Root cause

`LaunchpadViewModel.visiblePages` filters by `isHidden` and `isMissing` but never checks `showSystemApplications` against `record.source == .systemApplications`. Toggling the preference saves JSON but the grid never re-filters.

### Fix

- ViewModel gains a `var showSystemApplications: Bool` property, initialized in `bootstrapScan()` from preferences.
- `visiblePages` adds a filter on both paths (search and grid): when `showSystemApplications == false`, exclude records where `source == .systemApplications`.
- `SettingsView.onChange(of: preferences.showSystemApplications)` calls `viewModel?.showSystemApplications = newValue` in addition to `savePreferences()`, triggering `@Observable` recomputation.

No filesystem rescan needed — purely a display filter.

---

## 3. Folder Drag-to-Reorder

### Interaction

- In `FolderPopupView`, direct drag (no long-press required) on any member tile reorders within the folder.
- Drag distance < 90pt: internal reorder (real-time array swap).
- Drag distance >= 90pt: existing drag-out logic (`onDragOutBegan`).

### Implementation

- Existing `DragGesture.onChanged` gains a reorder branch: compute target index in the 5-column grid from pointer position relative to member frames, call `onReorder(appID, newIndex)`.
- New callback on `FolderPopupView`: `var onReorder: ((String, Int) -> Void)?`
- `LayoutStore` new method:
  ```swift
  mutating func reorderFolderItem(folderID: String, appID: String, toIndex: Int) {
      guard let fi = layout.folders.firstIndex(where: { $0.id == folderID }) else { return }
      layout.folders[fi].items.removeAll { $0 == appID }
      let clamped = min(max(0, toIndex), layout.folders[fi].items.count)
      layout.folders[fi].items.insert(appID, at: clamped)
      layout.folders[fi].updatedAt = Date()
  }
  ```
- ViewModel exposes `reorderInFolder(folderID:appID:toIndex:)` that calls LayoutStore + persists.
- Dragged tile: scale 1.1x + shadow (reuse existing `isBeingDragged` style).
- Member frames tracked via a local `@State` dictionary updated by `GeometryReader` or `onGeometryChange` in each cell.

---

## 4. Show Hidden Apps in Search

### Preference

- `UserPreferences` new field: `var showHiddenInSearch: Bool = true`
- Added to `CodingKeys`; decoder uses `decodeIfPresent` with `?? true`.

### Search logic

- `visiblePages` search path: when `showHiddenInSearch == true`, include records where `isHidden == true` (still exclude `isMissing`). When false, current behavior (exclude hidden).

### Visual indicator

- `LaunchpadDisplayItem` gains `var isHiddenApp: Bool = false`.
- Search path sets `isHiddenApp = record.isHidden` when building items.
- `SearchResultsView` (or `AppIconView`): when `isHiddenApp == true`, overlay a small badge at bottom-right:
  - SF Symbol `eye.fill`, ~10pt, white on a semi-transparent black circle (~16pt diameter).

### Settings placement

- In `AppManagementSettingsView`, above the hidden apps list:
  - Toggle: 「在搜索中显示隐藏应用」bound to `preferences.showHiddenInSearch`.

---

## Files to modify

| File | Change |
|------|--------|
| `Views/SettingsView.swift` | Restructure into NavigationSplitView + 4 sub-views |
| `Models/UserPreferences.swift` | Add `showHiddenInSearch` field |
| `Stores/LaunchpadViewModel.swift` | Add `showSystemApplications` property, fix `visiblePages` filter, add `reorderInFolder`, add `showHiddenInSearch` property |
| `Stores/LayoutStore.swift` | Add `reorderFolderItem` method |
| `Views/FolderPopupView.swift` | Add internal reorder logic in DragGesture, add `onReorder` callback |
| `Views/SearchResultsView.swift` | Pass `isHiddenApp` to icon view |
| `Views/AppIconView.swift` | Add eye badge overlay when `isHiddenApp` |
| `Stores/LaunchpadViewModel.swift` | Add `isHiddenApp` to `LaunchpadDisplayItem` struct |
| `Support/Localizer.swift` | New i18n keys |
| `Services/SettingsWindowController.swift` | Adjust window size to ~700x520 |

## Testing

- Unit test: `reorderFolderItem` moves item correctly, clamps index.
- Unit test: `visiblePages` excludes system apps when `showSystemApplications == false`.
- Unit test: search includes hidden apps when `showHiddenInSearch == true`, excludes when false.
- Manual: verify sidebar navigation, about page icon updates on style change, drag reorder in folder, eye badge in search results.
