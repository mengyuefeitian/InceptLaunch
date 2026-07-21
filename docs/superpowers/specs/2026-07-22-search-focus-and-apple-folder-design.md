# 搜索框自动聚焦 + Apple 官方应用自动成夹 — 设计文档

日期：2026-07-22
状态：已批准，待实现

## 背景

InceptLaunch 是 macOS Launchpad 替代品（SwiftPM + SwiftUI + AppKit）。本次新增两个体验改进：

1. 打开 overlay 后无需鼠标点击，键盘输入直接进入搜索框开始搜索（与原生 Launchpad 一致）。
2. 自动将苹果官方应用统一收纳进一个文件夹，减少网格杂乱。

## 功能 1：打开即聚焦搜索框

### 现状

- `SearchFieldView` 是一个无焦点管理的 `TextField`。
- `OverlayWindowController.show()` 每次显示都新建 `NSHostingView(rootView: ContentView())`，即 `ContentView` 每次打开都重建，`@State` 全部重置（搜索文本也清空，符合预期）。
- overlay 窗口 `canBecomeKey == true`，`show()` 里执行 `makeKeyAndOrderFront` + `NSApp.activate`，因此 TextField 可以接收键盘输入。

### 设计

- `ContentView` 持有 `@FocusState private var searchFocused: Bool`。
- `SearchFieldView` 增加 `@FocusState.Binding var focused: Bool`，TextField 上挂 `.focused($focused)`。
- `ContentView.onAppear` 中请求焦点。macOS 上焦点请求若在窗口成为 key window 之前发出会丢失，因此用极短异步延迟确保稳定：

```swift
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        searchFocused = true
    }
}
```

- 每次打开 overlay 都重建 ContentView → onAppear 每次都触发 → 每次打开都自动聚焦。
- Esc 行为不变（先关文件夹弹窗，否则关闭 overlay），由现有 `.onExitCommand` 处理。

### 验证

SwiftUI 焦点状态无法单元测试，靠真机验证：打开 overlay 后直接打字，字符应出现在搜索框并实时过滤网格。

## 功能 2：Apple 官方应用自动成夹

### 判定标准

应用的 `bundleID` 以 `com.apple.` 开头即视为苹果官方应用。覆盖 /System/Applications 下全部系统应用，也包含安装在 /Applications 的苹果应用（如 Xcode `com.apple.dt.Xcode`）。`AppRecord.bundleID` 为可选值，nil 时不视为苹果应用。

### 文件夹标识

- 稳定 ID：`folder:apple`。区别于用户拖拽建的 `folder:<UUID>` 和目录文件夹 `dir:<路径>`。
- 默认名称：`Apple`。
- 可通过现有 `renameFolder` 重命名（如改成"苹果"）；ID 不变，后续新应用仍自动进同一个夹。

### 成员策略（只收新装的）

在 `bootstrapScan()` 的扫描合并阶段处理：

- **首次**：若布局中不存在 `folder:apple`，且可见（非隐藏）苹果应用 ≥ 2 个，则创建文件夹，把这些苹果应用从网格页面收进文件夹。文件夹放置在第一个成员应用原来所在的页面/位置（复用 `createFolder` 的定位逻辑）。
- **之后每次启动**：仅把「新安装且尚未出现在任何位置（不在任何页面、也不在任何文件夹成员列表里）」的苹果应用加入 `folder:apple`。
- **尊重用户整理**：用户手动拖出文件夹的苹果应用会落在某个页面上，判定为"已安置"，不会被抓回文件夹。用户手动放进其它文件夹的苹果应用同理（已在某文件夹成员列表里），不动。
- 隐藏应用（`hiddenAppIDs`）不收进夹。
- 卸载的苹果应用由现有 `pruneApps` 自动从文件夹成员列表清除。

### 与扫描合并的集成

在 `applyScanResult` 中分流：

1. 从 `result.records` 计算苹果应用 ID 集合（bundleID 前缀判定）。
2. 调用新增的 `LayoutStore.syncAppleFolder(appleAppIDs:name:now:)`：
   - 文件夹已存在 → 把"不在任何页面且不在任何文件夹"的苹果应用 ID 追加进成员列表。
   - 文件夹不存在且苹果应用 ≥ 2 → 创建 `folder:apple`，成员为全部传入的苹果应用，从页面移除这些应用，并在第一个成员原位置插入文件夹项。
3. 传给 `appendNewApps` 的 topLevel 列表排除苹果应用 ID，使新装苹果应用直接进夹、不再先落到网格上。

### 边界情况

- 苹果应用少于 2 个时不建夹（实际系统应用约 35 个，几乎不会触发）。
- `folder:apple` 若因手动编辑 layout.json 等原因消失，下次启动按"首次"逻辑重建。
- 目录文件夹（`dir:` 前缀）优先级不变；理论上不会有苹果应用落在目录文件夹里，若出现则视为"已安置"，不重复收纳。

## 测试计划

### LayoutStoreTests（新增 4 个）

1. `syncAppleFolderCreatesFolderForAppleApps`：无文件夹时传入 ≥2 个苹果应用 → 创建 `folder:apple`，成员正确，应用从页面移除，文件夹项出现在页面上。
2. `syncAppleFolderAddsOnlyNewApps`：已有 `folder:apple`，一个苹果应用散落在页面上（模拟用户拖出）、一个全新苹果应用不在布局里 → 仅全新的被加入，散落的不被抓回。
3. `syncAppleFolderSkipsWhenFewerThanTwo`：仅 1 个苹果应用且无文件夹 → 不创建文件夹。
4. `syncAppleFolderKeepsWorkingAfterRename`：把 `folder:apple` 重命名为"苹果"后再次同步 → 新应用仍加入同一 ID 的文件夹。

### LaunchpadViewModelTests（新增 1 个）

5. `bootstrapRoutesAppleAppsToAppleFolder`：构造含 com.apple.* 与非苹果应用的记录，临时持久化文件，执行 bootstrapScan → 苹果应用不出现在网格顶层页面、全部位于 `folder:apple` 成员里；非苹果应用正常出现在网格。

### 真机验证

- 搜索焦点：打开 overlay 直接打字，确认字符进入搜索框并过滤。
- Apple 文件夹：打开 overlay 确认出现 Apple 文件夹，点进去确认系统应用都在里面。

## 涉及文件

- `Sources/InceptLaunch/Views/SearchFieldView.swift`（焦点绑定）
- `Sources/InceptLaunch/Views/ContentView.swift`（@FocusState + onAppear）
- `Sources/InceptLaunch/Stores/LayoutStore.swift`（syncAppleFolder）
- `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift`（applyScanResult 分流）
- `Tests/InceptLaunchTests/LayoutStoreTests.swift`
- `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift`
