# InceptLaunch v0.4 功能设计规格

日期：2026-07-23

## 概述

本次迭代包含 1 个关键 bug 修复和 4 个新功能，对应路线图 v0.4「完整复刻」阶段。

---

## 1. Bug 修复：单击空白区域即退出（第 4 次反馈）

### 根因

ContentView 背景 Rectangle 使用 `.onTapGesture { dismiss() }`。搜索框在 overlay 出现时自动获焦（`searchFocused = true`），当 TextField 持有焦点时，第一次鼠标点击被 AppKit 用于"取消焦点"（defocus），事件不会传递到 SwiftUI 的 `onTapGesture`。第二次点击时焦点已释放，gesture 才响应。

SearchResultsView 已用 `.simultaneousGesture(TapGesture())` 修复了同一问题（搜索模式下），但非搜索模式（主网格）的背景仍是 `.onTapGesture`。

### 修复方案

ContentView 背景 Rectangle 的 `.onTapGesture { dismiss() }` 改为 `.simultaneousGesture(TapGesture().onEnded { dismiss() })`。simultaneous gesture 不参与焦点仲裁，第一次点击即触发。

### 验证

- 非搜索模式：单击空白区域，overlay 立即消失。
- 搜索模式：同上（已有 simultaneousGesture，确认不退化）。
- 点击 app tile：启动 app 并退出（simultaneous 在 tile 上也会触发 dismiss，但 handleTap 已先 dismiss，无副作用）。
- 文件夹弹窗打开时：单击弹窗外背景关闭弹窗而非退出整个 overlay（需确认 FolderPopupView 的背景层拦截事件）。

---

## 2. 整理桌面（右键空白 → 全局压实）

### 交互

- 鼠标右键点击网格空白区域（非 tile），弹出 NSMenu，包含「整理桌面」选项。
- 点击后：所有页的 app/文件夹向前补位，填满每页空位，删除末尾空页。
- 布局持久化。

### 实现

- ContentView 背景层增加 `.contextMenu`（或右键时通过 NSEvent 弹出原生菜单）。由于背景是 Rectangle + simultaneousGesture，用 SwiftUI `.contextMenu` 最简。
- 调用 ViewModel 新增方法 `tidyGrid()`，内部调用 LayoutStore 已有的 `compactPages()`（已实现，当前仅 syncAppleFolder 内部调用），然后 persistLayout。
- 需要将 `compactPages()` 从 private 改为 internal 或新增 public 包装方法。

---

## 3. 文件夹放大 / 缩小

### 交互

- 右键文件夹 tile → 菜单增加「放大文件夹」（已放大时显示「缩小文件夹」）。
- 放大后：该文件夹 tile 在网格中占 2 行 × 2 列位置，其他 app 自动后移。
- 放大后的文件夹 tile 内部以 3×3 网格展示成员应用图标。
- 成员超过 9 个时，内部支持左右轮播翻页（小圆点指示器）。
- 缩小后恢复 1×1 tile（2×2 预览）。

### 数据模型

- `LaunchpadLayout` 新增 `enlargedFolderIDs: Set<String>`（Codable，默认空集）。
- 持久化到 layout JSON。

### 网格布局

- LaunchpadGridView 的 LazyVGrid 无法直接让单个 cell 跨多行多列。方案：改用自定义 `Grid` 或手动计算 frame。
- 推荐方案：在 pageGrid 中，遍历 page items 时，如果 item 是 enlarged folder，给它 `.frame(width: tileWidth*2 + columnSpacing, height: tileHeight*2 + rowSpacing)` 并用 LazyVGrid 的 `GridItem(.adaptive)` 或改用 flow layout。
- 更稳健方案：将 page 渲染从 LazyVGrid 改为自定义 Layout（SwiftUI Layout protocol），支持 2×2 span。这是最灵活的做法。

### 放大文件夹 tile 视图

- 新建 `EnlargedFolderTileView`：
  - 3×3 网格显示成员图标（RealAppIcon）。
  - 超过 9 个成员：TabView(.page) 或 HStack + offset 轮播，底部小圆点。
  - 点击成员图标：启动 app 并退出 overlay。
  - 背景：液态玻璃材质。

### 其他 app 后移

- 放大文件夹占 2×2 = 4 个 cell 位，相当于从当前页"消耗"4 个位置。repaginate 时需将 enlarged folder 计为 4 个 cell。
- 修改 `compactPages()` / `repaginate()` 的容量计算：enlarged folder 占 4 格。

---

## 4. macOS 26 液态玻璃特效

### 范围

全面应用：背景、文件夹弹窗面板、搜索框、tile 底板、放大文件夹背景。

### 实现

- macOS 26 SDK 提供 `.glassEffect(in:)` modifier 和 `GlassEffectContainer`。
- 用 `#available(macOS 26, *)` 条件编译：
  - 可用时：使用 `.glassEffect(.regular, in: .rect(cornerRadius:))` 或 `GlassEffectContainer`。
  - 不可用时：fallback 到现有 `.ultraThinMaterial` / `.ultraThickMaterial`。
- 背景：从 `.black.opacity(0.55) + .ultraThinMaterial` 改为 glass effect（带模糊和折射）。
- 搜索框：Capsule 背景从 `.regularMaterial` 改为 glass。
- 文件夹弹窗：面板从 `.ultraThickMaterial` 改为 glass。
- Tile 底板（FolderTileView）：从 `.white.opacity(0.16)` 改为 glass。

### 注意

- 当前项目 `platforms: [.macOS(.v15)]`，需确认 macOS 26 API 的 availability 标注。如果 Swift 6.3 SDK 包含 macOS 26 API，用 `if #available` 即可。否则需提升 deployment target 或条件编译。
- 如果当前 SDK 不含 glass API（需 macOS 26 SDK），则用 material 模拟增强（增加 blur radius、border glow、refraction 渐变），视觉上接近液态玻璃。

---

## 5. 应用图标切换（设置）

### 交互

- 设置窗口增加「应用图标」section，展示 A / B / D 三套图标的缩略图。
- 用户点选后，Dock 图标和菜单栏图标实时替换，无需重启。
- 选择持久化到 UserPreferences。

### 实现

- 将 A、B、D 三套图标的 icns/png 资源放入 `Resources/Icons/`（A = concept_A, B = concept_B, D = final_D / 当前默认）。
- `UserPreferences` 新增 `appIconStyle: String`（"A" / "B" / "D"，默认 "D"）。
- 切换时：
  ```swift
  NSApp.applicationIconImage = NSImage(named: "IconA") // 或从 bundle path 加载
  ```
  这会同时更新 Dock 和 app 切换器中的图标。
- 菜单栏图标（如果有自定义）也同步更新。
- 注意：`NSApp.applicationIconImage` 只影响运行时显示，不改变 .app bundle 里的 .icns。Finder 中仍显示 bundle 的默认图标。这是预期行为（macOS 限制）。

### 设置 UI

- SettingsView 新增 Section("应用图标")，HStack 展示 3 个 64×64 缩略图，选中态加蓝色边框。

---

## 文件变更清单

| 文件 | 变更 |
|------|------|
| Views/ContentView.swift | bug 修复 + 右键菜单「整理桌面」 |
| Views/LaunchpadGridView.swift | 支持 enlarged folder 2×2 渲染 |
| Views/EnlargedFolderTileView.swift | 新建：3×3 内部网格 + 轮播 |
| Views/FolderPopupView.swift | 液态玻璃材质 |
| Views/SearchFieldView.swift | 液态玻璃材质 |
| Views/AppIconView.swift | FolderTileView 液态玻璃 |
| Views/SettingsView.swift | 图标切换 section |
| Views/TileTrashMenu.swift | 文件夹右键增加放大/缩小 |
| Stores/LaunchpadViewModel.swift | tidyGrid() + enlargeFolder() + shrinkFolder() |
| Stores/LayoutStore.swift | compactPages 改 internal + enlarged 容量计算 |
| Models/LaunchpadLayout.swift | enlargedFolderIDs 字段 |
| Models/UserPreferences.swift | appIconStyle 字段 |
| Services/OverlayWindowController.swift | 无变更 |
| Resources/Icons/ | 新增 A/B 图标资源 |

## 测试策略

- LayoutStoreTests：compactPages 全局压实、enlarged folder 容量计算。
- 手动验证：单击退出（非搜索 + 搜索模式）、右键整理、文件夹放大/缩小/轮播、图标切换。
