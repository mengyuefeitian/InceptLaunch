# Settings Restructure & Feature Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure settings into a sidebar-navigated UI, fix system app toggle, add folder drag-reorder, and show hidden apps in search with an eye badge.

**Architecture:** Four independent features touching model, store, view-model, and view layers. The model/store changes are tested first (TDD), then view-layer changes build on top. Settings UI is restructured last since it depends on the new preference field.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (NSHostingView), Swift Testing framework, SPM

## Global Constraints

- macOS 15.0+ deployment target
- Swift 6.2 strict concurrency
- No external dependencies (SPM-only, zero packages)
- All user-facing strings go through `Localizer.t()` with both `enStrings` and `zhStrings` entries
- Preferences JSON must remain backward-compatible (new fields use `decodeIfPresent` with defaults)
- Test framework: Swift Testing (`import Testing`, `@Test`, `#expect`)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `Sources/InceptLaunch/Models/UserPreferences.swift` | Add `showHiddenInSearch` field |
| `Sources/InceptLaunch/Stores/LayoutStore.swift` | Add `reorderFolderItem` method |
| `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift` | Add `showSystemApplications`/`showHiddenInSearch` properties, fix `visiblePages`, add `reorderInFolder`, add `isHiddenApp` to `LaunchpadDisplayItem` |
| `Sources/InceptLaunch/Views/FolderPopupView.swift` | Internal drag-reorder logic |
| `Sources/InceptLaunch/Views/AppIconView.swift` | Eye badge overlay |
| `Sources/InceptLaunch/Views/SearchResultsView.swift` | Pass `isHiddenApp` through |
| `Sources/InceptLaunch/Views/SettingsView.swift` | Restructure into NavigationSplitView + 4 sub-views |
| `Sources/InceptLaunch/Services/SettingsWindowController.swift` | Window size 700x520 |
| `Sources/InceptLaunch/Support/Localizer.swift` | New i18n keys |
| `Tests/InceptLaunchTests/LayoutStoreTests.swift` | Test `reorderFolderItem` |
| `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift` | Test system-app filter, hidden-in-search, reorder |

---

### Task 1: Model & Store Layer — `showHiddenInSearch` preference + `reorderFolderItem`

**Files:**
- Modify: `Sources/InceptLaunch/Models/UserPreferences.swift`
- Modify: `Sources/InceptLaunch/Stores/LayoutStore.swift`
- Test: `Tests/InceptLaunchTests/LayoutStoreTests.swift`

**Interfaces:**
- Produces: `UserPreferences.showHiddenInSearch: Bool` (default `true`)
- Produces: `LayoutStore.reorderFolderItem(folderID: String, appID: String, toIndex: Int)`

- [ ] **Step 1: Write failing test for `reorderFolderItem`**

Add to `Tests/InceptLaunchTests/LayoutStoreTests.swift`:

```swift
@Test func reorderFolderItemMovesAppToNewIndex() {
    var store = LayoutStore(layout: .init(
        pages: [[.folder("folder:test")]],
        folders: [LaunchpadFolder(
            id: "folder:test",
            name: "Test",
            items: ["a", "b", "c", "d"],
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))

    store.reorderFolderItem(folderID: "folder:test", appID: "d", toIndex: 0)
    #expect(store.layout.folders[0].items == ["d", "a", "b", "c"])

    store.reorderFolderItem(folderID: "folder:test", appID: "a", toIndex: 3)
    #expect(store.layout.folders[0].items == ["d", "b", "c", "a"])
}

@Test func reorderFolderItemClampsOutOfBoundsIndex() {
    var store = LayoutStore(layout: .init(
        pages: [[.folder("folder:test")]],
        folders: [LaunchpadFolder(
            id: "folder:test",
            name: "Test",
            items: ["a", "b"],
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))

    store.reorderFolderItem(folderID: "folder:test", appID: "a", toIndex: 99)
    #expect(store.layout.folders[0].items == ["b", "a"])

    store.reorderFolderItem(folderID: "folder:test", appID: "b", toIndex: -5)
    #expect(store.layout.folders[0].items == ["b", "a"])
}

@Test func reorderFolderItemIgnoresUnknownFolder() {
    var store = LayoutStore(layout: .init(
        pages: [[.folder("folder:test")]],
        folders: [LaunchpadFolder(
            id: "folder:test",
            name: "Test",
            items: ["a", "b"],
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))

    store.reorderFolderItem(folderID: "folder:nonexistent", appID: "a", toIndex: 1)
    #expect(store.layout.folders[0].items == ["a", "b"])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test --filter reorderFolderItem 2>&1 | tail -20`
Expected: Compilation error — `reorderFolderItem` not defined.

- [ ] **Step 3: Implement `reorderFolderItem` in LayoutStore**

Add to `Sources/InceptLaunch/Stores/LayoutStore.swift` after the `renameFolder` method:

```swift
mutating func reorderFolderItem(folderID: String, appID: String, toIndex: Int) {
    guard let fi = layout.folders.firstIndex(where: { $0.id == folderID }) else { return }
    layout.folders[fi].items.removeAll { $0 == appID }
    let clamped = min(max(0, toIndex), layout.folders[fi].items.count)
    layout.folders[fi].items.insert(appID, at: clamped)
    layout.folders[fi].updatedAt = Date()
}
```

- [ ] **Step 4: Add `showHiddenInSearch` to UserPreferences**

In `Sources/InceptLaunch/Models/UserPreferences.swift`:

1. Add property after `animateSearch`:
```swift
var showHiddenInSearch: Bool = true
```

2. Add to `CodingKeys`:
```swift
case showHiddenInSearch
```

3. Add to the memberwise `init` parameter list (after `animateSearch: Bool = true`):
```swift
showHiddenInSearch: Bool = true
```
And in the body:
```swift
self.showHiddenInSearch = showHiddenInSearch
```

4. Add to `init(from decoder:)` after the `animateSearch` decode:
```swift
showHiddenInSearch = (try? c.decodeIfPresent(Bool.self, forKey: .showHiddenInSearch)) ?? true
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test --filter reorderFolderItem 2>&1 | tail -20`
Expected: All 3 tests PASS.

- [ ] **Step 6: Run full test suite to check for regressions**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test 2>&1 | tail -30`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/xiaoan/Documents/code/InceptLaunch
git add Sources/InceptLaunch/Models/UserPreferences.swift Sources/InceptLaunch/Stores/LayoutStore.swift Tests/InceptLaunchTests/LayoutStoreTests.swift
git commit -m "feat: add showHiddenInSearch preference and reorderFolderItem to LayoutStore"
```

---

### Task 2: ViewModel — System App Filter Fix + Hidden-in-Search + Reorder

**Files:**
- Modify: `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift`
- Test: `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift`

**Interfaces:**
- Consumes: `UserPreferences.showHiddenInSearch`, `LayoutStore.reorderFolderItem(folderID:appID:toIndex:)`
- Produces: `LaunchpadViewModel.showSystemApplications: Bool`, `LaunchpadViewModel.showHiddenInSearch: Bool`, `LaunchpadViewModel.reorderInFolder(folderID:appID:toIndex:)`, `LaunchpadDisplayItem.isHiddenApp: Bool`

- [ ] **Step 1: Write failing test for system app filtering**

Add to `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift`:

```swift
@MainActor @Test func systemAppsHiddenWhenToggleOff() {
    let systemApp = AppRecord(
        id: "bundle:com.apple.Safari",
        bundleID: "com.apple.Safari",
        name: "Safari",
        localizedName: "Safari",
        path: "/System/Applications/Safari.app",
        iconCacheKey: "safari",
        version: nil,
        source: .systemApplications,
        isHidden: false,
        isMissing: false,
        lastSeenAt: Date(timeIntervalSince1970: 1),
        lastLaunchedAt: nil
    )
    let userApp = makeRecord("Editor")
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            systemApp.id: systemApp,
            userApp.id: userApp
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(systemApp.id), .app(userApp.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.showSystemApplications = false
    let visible = viewModel.visiblePages.flatMap { $0 }
    #expect(visible.map(\.id) == [userApp.id])

    viewModel.showSystemApplications = true
    let visibleAgain = viewModel.visiblePages.flatMap { $0 }
    #expect(visibleAgain.map(\.id) == [systemApp.id, userApp.id])
}

@MainActor @Test func searchIncludesHiddenAppsWhenEnabled() {
    let hiddenApp = AppRecord(
        id: "bundle:com.example.Secret",
        bundleID: "com.example.Secret",
        name: "Secret",
        localizedName: "Secret",
        path: "/Applications/Secret.app",
        iconCacheKey: "secret",
        version: nil,
        source: .localApplications,
        isHidden: true,
        isMissing: false,
        lastSeenAt: Date(timeIntervalSince1970: 1),
        lastLaunchedAt: nil
    )
    let normalApp = makeRecord("Notes")
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            hiddenApp.id: hiddenApp,
            normalApp.id: normalApp
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(normalApp.id)]],
            folders: [],
            hiddenAppIDs: [hiddenApp.id],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.showHiddenInSearch = true
    viewModel.searchText = "sec"
    let results = viewModel.visiblePages.flatMap { $0 }
    #expect(results.map(\.id) == [hiddenApp.id])
    #expect(results[0].isHiddenApp == true)

    viewModel.showHiddenInSearch = false
    let resultsHidden = viewModel.visiblePages.flatMap { $0 }
    #expect(resultsHidden.isEmpty)
}

@MainActor @Test func reorderInFolderUpdatesLayoutAndPersists() throws {
    let appA = makeRecord("Alpha")
    let appB = makeRecord("Beta")
    let appC = makeRecord("Gamma")
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: tempURL))
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            appA.id: appA, appB.id: appB, appC.id: appC
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.folder("folder:test")]],
            folders: [LaunchpadFolder(
                id: "folder:test",
                name: "Test",
                items: [appA.id, appB.id, appC.id],
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 1)
            )],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace()),
        layoutPersistence: persistence
    )

    viewModel.reorderInFolder(folderID: "folder:test", appID: appC.id, toIndex: 0)

    let saved = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: tempURL)
    )
    #expect(saved.folders[0].items == [appC.id, appA.id, appB.id])
    try? FileManager.default.removeItem(at: tempURL)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test --filter "systemAppsHidden|searchIncludesHidden|reorderInFolder" 2>&1 | tail -20`
Expected: Compilation errors — `showSystemApplications`, `showHiddenInSearch`, `isHiddenApp`, `reorderInFolder` not defined.

- [ ] **Step 3: Add `isHiddenApp` to `LaunchpadDisplayItem`**

In `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift`, modify the struct:

```swift
struct LaunchpadDisplayItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case app(AppRecord)
        case folder(LaunchpadFolder)
    }

    var id: String
    var title: String
    var kind: Kind
    var members: [AppRecord] = []
    var isHiddenApp: Bool = false
}
```

- [ ] **Step 4: Add `showSystemApplications` and `showHiddenInSearch` properties to ViewModel**

In `LaunchpadViewModel`, add after `var currentPage = 0`:

```swift
var showSystemApplications: Bool = true
var showHiddenInSearch: Bool = true
```

- [ ] **Step 5: Fix `visiblePages` to filter system apps and include hidden apps in search**

Replace the `visiblePages` computed property:

```swift
var visiblePages: [[LaunchpadDisplayItem]] {
    let recordsByID = appIndex.records

    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return [matcher.ranked(query: searchText, records: Array(recordsByID.values))
            .filter { record in
                if record.isMissing { return false }
                if record.isHidden && !showHiddenInSearch { return false }
                if !showSystemApplications && record.source == .systemApplications { return false }
                return true
            }
            .map { LaunchpadDisplayItem(id: $0.id, title: $0.name, kind: .app($0), isHiddenApp: $0.isHidden) }]
    }

    return layoutStore.layout.pages.map { page in
        page.compactMap { item in
            switch item {
            case .app(let id):
                guard let record = recordsByID[id], !record.isHidden, !record.isMissing else { return nil }
                if !showSystemApplications && record.source == .systemApplications { return nil }
                return LaunchpadDisplayItem(id: id, title: record.name, kind: .app(record))
            case .folder(let id):
                guard let folder = layoutStore.layout.folders.first(where: { $0.id == id }) else { return nil }
                let members = folder.items
                    .compactMap { recordsByID[$0] }
                    .filter { !$0.isHidden && !$0.isMissing }
                return LaunchpadDisplayItem(id: id, title: folder.name, kind: .folder(folder), members: members)
            }
        }
    }
}
```

- [ ] **Step 6: Add `reorderInFolder` method to ViewModel**

Add after `renameFolder`:

```swift
func reorderInFolder(folderID: String, appID: String, toIndex: Int) {
    layoutStore.reorderFolderItem(folderID: folderID, appID: appID, toIndex: toIndex)
    persistLayout()
}
```

- [ ] **Step 7: Initialize properties in `bootstrapScan`**

In `bootstrapScan()`, after `let preferences = (try? preferencesStore.load()) ?? .default`, add:

```swift
showSystemApplications = preferences.showSystemApplications
showHiddenInSearch = preferences.showHiddenInSearch
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test --filter "systemAppsHidden|searchIncludesHidden|reorderInFolder" 2>&1 | tail -20`
Expected: All 3 tests PASS.

- [ ] **Step 9: Run full test suite**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test 2>&1 | tail -30`
Expected: All tests PASS.

- [ ] **Step 10: Commit**

```bash
cd /Users/xiaoan/Documents/code/InceptLaunch
git add Sources/InceptLaunch/Stores/LaunchpadViewModel.swift Tests/InceptLaunchTests/LaunchpadViewModelTests.swift
git commit -m "feat: fix system app toggle, add hidden-in-search and folder reorder to ViewModel"
```

---

### Task 3: FolderPopupView — Drag-to-Reorder Inside Folders

**Files:**
- Modify: `Sources/InceptLaunch/Views/FolderPopupView.swift`

**Interfaces:**
- Consumes: `LaunchpadViewModel.reorderInFolder(folderID:appID:toIndex:)`
- Produces: New callback `onReorder: ((String, Int) -> Void)?` on `FolderPopupView`

- [ ] **Step 1: Add `onReorder` callback and member frame tracking**

In `Sources/InceptLaunch/Views/FolderPopupView.swift`, add a new property after `onDragOutEnded`:

```swift
var onReorder: ((String, Int) -> Void)? = nil
```

Add state for tracking member frames, after `@State private var leftFolder = false`:

```swift
@State private var memberFrames: [String: CGRect] = [:]
@State private var reorderDragID: String? = nil
```

- [ ] **Step 2: Add frame tracking to each member cell**

In the `folderMemberCell` function, wrap the existing `TimelineView` content with frame reporting. After the `.gesture(DragGesture(...))` block, add a background geometry reader:

```swift
.background(
    GeometryReader { geo in
        Color.clear
            .onAppear {
                memberFrames[member.id] = geo.frame(in: .named("folderGrid"))
            }
            .onChange(of: geo.frame(in: .named("folderGrid"))) { _, newFrame in
                memberFrames[member.id] = newFrame
            }
    }
)
```

Add `.coordinateSpace(name: "folderGrid")` to the `LazyVGrid` in the body:

```swift
LazyVGrid(columns: columns, spacing: 24) {
    ForEach(item.members) { member in
        folderMemberCell(member: member)
    }
}
.coordinateSpace(name: "folderGrid")
```

- [ ] **Step 3: Add reorder logic to the DragGesture**

Replace the existing `DragGesture` in `folderMemberCell` with reorder-aware logic. The key change is in `.onChanged`: when distance < 90pt, compute the target index from the pointer position and call `onReorder`. When distance >= 90pt, trigger the existing drag-out.

Replace the `.gesture(DragGesture(...))` block:

```swift
.gesture(
    DragGesture(minimumDistance: 6, coordinateSpace: .named("folderGrid"))
        .onChanged { value in
            if leftFolder { return }

            let distance = hypot(value.translation.width, value.translation.height)

            if distance >= 90 {
                leftFolder = true
                reorderDragID = nil
                NotificationCenter.default.post(
                    name: .inceptLaunchEditDragChanged,
                    object: EditDragUpdate(id: member.id, translation: value.translation)
                )
                onDragOutBegan?(member.id, value.location)
            } else {
                reorderDragID = member.id
                let targetIndex = computeReorderIndex(
                    dragID: member.id,
                    location: value.location
                )
                if let targetIndex,
                   let currentIndex = item.members.firstIndex(where: { $0.id == member.id }),
                   targetIndex != currentIndex {
                    onReorder?(member.id, targetIndex)
                }
            }
        }
        .onEnded { _ in
            if !leftFolder {
                reorderDragID = nil
            }
            leftFolder = false
        }
)
```

- [ ] **Step 4: Add `computeReorderIndex` helper**

Add a private method to `FolderPopupView`:

```swift
private func computeReorderIndex(dragID: String, location: CGPoint) -> Int? {
    let sorted = item.members.enumerated()
        .compactMap { (index, member) -> (Int, CGRect)? in
            guard let frame = memberFrames[member.id] else { return nil }
            return (index, frame)
        }
        .sorted { $0.1.minY < $1.1.minY || ($0.1.minY == $1.1.minY && $0.1.minX < $1.1.minX) }

    for (index, frame) in sorted {
        if location.x < frame.midX && location.y < frame.maxY {
            return index
        }
    }
    return item.members.count - 1
}
```

- [ ] **Step 5: Update drag visual to use `reorderDragID`**

In `folderMemberCell`, update the `isBeingDragged` computation:

```swift
let isBeingDragged = (editDragID == member.id && !leftFolder) || reorderDragID == member.id
```

- [ ] **Step 6: Wire up `onReorder` in ContentView**

Find where `FolderPopupView` is instantiated in `ContentView.swift` and add the `onReorder` callback:

```swift
onReorder: { appID, newIndex in
    if case .folder(let folder) = openFolderItem.kind {
        viewModel.reorderInFolder(folderID: folder.id, appID: appID, toIndex: newIndex)
        // Update the open folder's members so the popup reflects the new order
        viewModel.refreshOpenFolder()
    }
}
```

Add `refreshOpenFolder()` to `LaunchpadViewModel`:

```swift
func refreshOpenFolder() {
    guard let folder = openFolder, case .folder(let f) = folder.kind else { return }
    guard let updated = layoutStore.layout.folders.first(where: { $0.id == f.id }) else { return }
    let recordsByID = appIndex.records
    let members = updated.items
        .compactMap { recordsByID[$0] }
        .filter { !$0.isHidden && !$0.isMissing }
    openFolder = LaunchpadDisplayItem(id: updated.id, title: updated.name, kind: .folder(updated), members: members)
}
```

- [ ] **Step 7: Build and verify compilation**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Run full test suite**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test 2>&1 | tail -30`
Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
cd /Users/xiaoan/Documents/code/InceptLaunch
git add Sources/InceptLaunch/Views/FolderPopupView.swift Sources/InceptLaunch/Views/ContentView.swift Sources/InceptLaunch/Stores/LaunchpadViewModel.swift
git commit -m "feat: support drag-to-reorder apps inside folder popups"
```

---

### Task 4: Eye Badge for Hidden Apps in Search Results

**Files:**
- Modify: `Sources/InceptLaunch/Views/AppIconView.swift`
- Modify: `Sources/InceptLaunch/Views/SearchResultsView.swift`

**Interfaces:**
- Consumes: `LaunchpadDisplayItem.isHiddenApp: Bool`
- Produces: Visual eye badge on hidden app tiles in search results

- [ ] **Step 1: Add eye badge overlay to `AppIconView`**

In `Sources/InceptLaunch/Views/AppIconView.swift`, add a new optional parameter and overlay:

```swift
struct AppIconView: View {
    let item: LaunchpadDisplayItem
    var iconSize: CGFloat = 104
    var tileHeight: CGFloat = 150
    var showHiddenBadge: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            iconView
                .frame(width: iconSize, height: iconSize)
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
            Text(item.title)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
        .frame(width: 132, height: tileHeight)
        .contentShape(Rectangle())
    }
```

- [ ] **Step 2: Pass `showHiddenBadge` in `SearchResultsView`**

In `Sources/InceptLaunch/Views/SearchResultsView.swift`, update the `AppIconView` instantiation:

```swift
AppIconView(
    item: item,
    iconSize: GridMetrics.iconSize,
    tileHeight: GridMetrics.tileHeight,
    showHiddenBadge: item.isHiddenApp
)
```

- [ ] **Step 3: Build and verify compilation**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run full test suite**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test 2>&1 | tail -30`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/xiaoan/Documents/code/InceptLaunch
git add Sources/InceptLaunch/Views/AppIconView.swift Sources/InceptLaunch/Views/SearchResultsView.swift
git commit -m "feat: add eye badge for hidden apps in search results"
```

---

### Task 5: Settings UI Restructure + About Page + Localization

**Files:**
- Modify: `Sources/InceptLaunch/Views/SettingsView.swift` (full rewrite)
- Modify: `Sources/InceptLaunch/Services/SettingsWindowController.swift`
- Modify: `Sources/InceptLaunch/Support/Localizer.swift`

**Interfaces:**
- Consumes: `UserPreferences.showHiddenInSearch`, `LaunchpadViewModel.showSystemApplications`, `LaunchpadViewModel.showHiddenInSearch`
- Produces: Sidebar-navigated settings with 4 categories, About page with dynamic icon

- [ ] **Step 1: Add localization keys**

In `Sources/InceptLaunch/Support/Localizer.swift`, add to `enStrings`:

```swift
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
```

Add to `zhStrings`:

```swift
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
```

- [ ] **Step 2: Rewrite `SettingsView.swift` with NavigationSplitView**

Replace the entire `SettingsView` body and structure. The file keeps `BackgroundImagePicker`, `BackgroundThumbnail`, `AppIconSmall`, and `IconThumbnailView` unchanged. The new `SettingsView`:

```swift
import SwiftUI
import UniformTypeIdentifiers

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general, interface, appManagement, about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return Localizer.t("settings.general")
        case .interface: return Localizer.t("settings.interface")
        case .appManagement: return Localizer.t("settings.appManagement")
        case .about: return Localizer.t("settings.about")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .interface: return "paintbrush"
        case .appManagement: return "square.grid.2x2"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var preferences = UserPreferences.default
    @State private var selectedCategory: SettingsCategory? = .general
    private let preferencesStore = PreferencesStore()
    weak var viewModel: LaunchpadViewModel?

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(category.label, systemImage: category.icon)
                    .tag(category)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        } detail: {
            switch selectedCategory {
            case .general:
                GeneralSettingsView(preferences: $preferences, onSave: savePreferences)
            case .interface:
                AppearanceSettingsView(preferences: $preferences, onSave: savePreferences)
            case .appManagement:
                AppManagementSettingsView(preferences: $preferences, viewModel: viewModel, onSave: savePreferences)
            case .about:
                AboutView(preferences: preferences)
            case nil:
                Text("")
            }
        }
        .frame(width: 700, height: 520)
        .onAppear {
            preferences = (try? preferencesStore.load()) ?? .default
            Localizer.setLanguage(preferences.language)
        }
        .onChange(of: preferences.language) { _, newLang in
            Localizer.setLanguage(newLang)
            savePreferences()
        }
    }

    private func savePreferences() {
        try? preferencesStore.save(preferences)
    }
}
```

- [ ] **Step 3: Create `GeneralSettingsView`**

Add below `SettingsView` in the same file:

```swift
struct GeneralSettingsView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    var body: some View {
        Form {
            Section(Localizer.t("settings.language")) {
                Picker("Language", selection: $preferences.language) {
                    ForEach(UserPreferences.Language.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            Section(Localizer.t("settings.animations")) {
                Toggle(Localizer.t("settings.animateIcons"), isOn: $preferences.animateIcons)
                Toggle(Localizer.t("settings.animatePageFlip"), isOn: $preferences.animatePageFlip)
                Toggle(Localizer.t("settings.animateFolder"), isOn: $preferences.animateFolder)
                Toggle(Localizer.t("settings.animateDrag"), isOn: $preferences.animateDrag)
                Toggle(Localizer.t("settings.animateSearch"), isOn: $preferences.animateSearch)
            }

            Section(Localizer.t("settings.launch")) {
                TextField(Localizer.t("settings.hotKey"), text: $preferences.hotKey)
                Toggle(Localizer.t("settings.launchAtLogin"), isOn: $preferences.launchAtLogin)
                Toggle(Localizer.t("settings.showMenuBarIcon"), isOn: $preferences.showMenuBarIcon)
                Toggle(Localizer.t("settings.showDockIcon"), isOn: $preferences.showDockIcon)
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.hotKey) { _, _ in onSave() }
        .onChange(of: preferences.launchAtLogin) { _, _ in onSave() }
        .onChange(of: preferences.showMenuBarIcon) { _, _ in onSave() }
        .onChange(of: preferences.showDockIcon) { _, _ in onSave() }
        .onChange(of: preferences.animateIcons) { _, _ in onSave() }
        .onChange(of: preferences.animatePageFlip) { _, _ in onSave() }
        .onChange(of: preferences.animateFolder) { _, _ in onSave() }
        .onChange(of: preferences.animateDrag) { _, _ in onSave() }
        .onChange(of: preferences.animateSearch) { _, _ in onSave() }
    }
}
```

- [ ] **Step 4: Create `AppearanceSettingsView`**

```swift
struct AppearanceSettingsView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    var body: some View {
        Form {
            Section(Localizer.t("settings.appearance")) {
                Slider(value: $preferences.backgroundBlur, in: 0...1) {
                    Text(Localizer.t("settings.backgroundBlur"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(Localizer.t("settings.appIcon")).font(.headline)
                    HStack(spacing: 12) {
                        ForEach(UserPreferences.AppIconStyle.allCases, id: \.self) { style in
                            IconThumbnailView(
                                style: style,
                                isSelected: preferences.appIconStyle == style
                            )
                            .onTapGesture {
                                preferences.appIconStyle = style
                                IconSwitcher.apply(style)
                                onSave()
                            }
                        }
                    }
                }
            }

            Section(Localizer.t("settings.background")) {
                Picker("Background mode", selection: $preferences.backgroundMode) {
                    Text(Localizer.t("settings.showDesktop")).tag(UserPreferences.BackgroundMode.desktop)
                    Text(Localizer.t("settings.uploadBackground")).tag(UserPreferences.BackgroundMode.uploaded)
                }
                .pickerStyle(.segmented)

                if preferences.backgroundMode == .uploaded {
                    BackgroundImagePicker(
                        images: $preferences.backgroundImages,
                        onSave: onSave
                    )
                    if preferences.backgroundImages.count >= 2 {
                        Toggle(Localizer.t("settings.autoCarousel"), isOn: $preferences.autoCarousel)
                        Text(preferences.autoCarousel
                             ? Localizer.t("settings.carouselHint")
                             : Localizer.t("settings.firstImageHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.backgroundBlur) { _, _ in onSave() }
        .onChange(of: preferences.backgroundMode) { _, _ in onSave() }
        .onChange(of: preferences.autoCarousel) { _, _ in onSave() }
    }
}
```

- [ ] **Step 5: Create `AppManagementSettingsView`**

```swift
struct AppManagementSettingsView: View {
    @Binding var preferences: UserPreferences
    weak var viewModel: LaunchpadViewModel?
    let onSave: () -> Void

    var body: some View {
        Form {
            Section(Localizer.t("settings.systemApps")) {
                Toggle(Localizer.t("settings.showSystemApps"), isOn: $preferences.showSystemApplications)
            }

            Section(Localizer.t("settings.hiddenApps")) {
                Toggle(Localizer.t("settings.showHiddenInSearch"), isOn: $preferences.showHiddenInSearch)

                if let vm = viewModel, !vm.hiddenApps.isEmpty {
                    ForEach(vm.hiddenApps) { record in
                        HStack {
                            AppIconSmall(record: record)
                            Text(record.name)
                            Spacer()
                            Button(Localizer.t("menu.unhide")) {
                                viewModel?.unhideApp(id: record.id)
                                onSave()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    Text(Localizer.t("settings.noHiddenApps"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.showSystemApplications) { _, newValue in
            viewModel?.showSystemApplications = newValue
            onSave()
        }
        .onChange(of: preferences.showHiddenInSearch) { _, newValue in
            viewModel?.showHiddenInSearch = newValue
            onSave()
        }
    }
}
```

- [ ] **Step 6: Create `AboutView`**

```swift
struct AboutView: View {
    let preferences: UserPreferences
    @State private var showCopied = false

    private var appIcon: NSImage? {
        let name = preferences.appIconStyle.resourceName
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSImage(named: name)
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Group {
                if let img = appIcon {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(radius: 4)

            Text("InceptLaunch")
                .font(.title2.weight(.semibold))

            Text("\(Localizer.t("about.version")) \(versionString)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                linkRow(label: Localizer.t("about.website"), value: "www.xiaoanhome.xyz") {
                    NSWorkspace.shared.open(URL(string: "https://www.xiaoanhome.xyz/")!)
                }
                linkRow(label: "X", value: "@countquery") {
                    NSWorkspace.shared.open(URL(string: "https://x.com/countquery")!)
                }
                linkRow(label: Localizer.t("about.wechatOA"), value: "mowenfeigong") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("mowenfeigong", forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                }
            }
            .padding(.top, 8)

            if showCopied {
                Text(Localizer.t("about.copied"))
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func linkRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: action) {
                Text(value)
                    .foregroundStyle(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
    }
}
```

- [ ] **Step 7: Update `SettingsWindowController` window size**

In `Sources/InceptLaunch/Services/SettingsWindowController.swift`, change the window size:

```swift
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
```

- [ ] **Step 8: Build and verify compilation**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

- [ ] **Step 9: Run full test suite**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift test 2>&1 | tail -30`
Expected: All tests PASS.

- [ ] **Step 10: Commit**

```bash
cd /Users/xiaoan/Documents/code/InceptLaunch
git add Sources/InceptLaunch/Views/SettingsView.swift Sources/InceptLaunch/Services/SettingsWindowController.swift Sources/InceptLaunch/Support/Localizer.swift
git commit -m "feat: restructure settings into sidebar navigation with About page"
```

---

### Task 6: Manual Verification & Final Integration

**Files:**
- All modified files from Tasks 1-5

- [ ] **Step 1: Build release binary**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && swift build -c release 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Launch the app and verify settings sidebar**

Run: `cd /Users/xiaoan/Documents/code/InceptLaunch && .build/release/InceptLaunch &`

Verify:
- Settings window opens at 700x520
- Sidebar shows 4 categories with icons
- Clicking each category switches the detail pane
- 通用: language picker, animation toggles, launch settings all work
- 界面: blur slider, icon picker, background settings all work
- 应用管理: system app toggle, hidden apps list, search toggle all present
- 关于: shows app icon matching current style, version, clickable links

- [ ] **Step 3: Verify system app toggle**

- Turn off "显示系统应用" in settings
- Close settings, open Launchpad overlay
- Confirm system apps (from /System/Applications) are gone from the grid
- Re-enable and confirm they return

- [ ] **Step 4: Verify folder drag reorder**

- Open a folder with 3+ apps
- Drag an app within the folder (short drag, < 90pt)
- Confirm it reorders in real-time
- Close and reopen the folder — order persists
- Drag an app > 90pt out of the folder — confirm existing drag-out behavior works

- [ ] **Step 5: Verify hidden apps in search**

- Hide an app via context menu
- Type its name in search
- Confirm it appears with an eye badge (when toggle is on)
- Turn off "在搜索中显示隐藏应用" in settings
- Search again — hidden app no longer appears

- [ ] **Step 6: Final commit (if any fixes needed)**

```bash
cd /Users/xiaoan/Documents/code/InceptLaunch
git add -A
git commit -m "fix: integration fixes for settings restructure and features"
```
