# Reorder Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add iOS-style real-time tile displacement animation when dragging apps to reorder in both the main grid and folder interiors.

**Architecture:** Live model reorder during drag — when the pointer crosses a cell boundary, `moveItem` is called inside `withAnimation(.spring(...))`. SwiftUI animates the custom Layout's position changes. The dragged tile is hidden in the grid and rendered as a floating overlay following the pointer. The `animateDrag` preference gates all animation.

**Tech Stack:** SwiftUI, custom `Layout` protocol (`LaunchpadGridLayout`), `@Observable` ViewModel, Swift Testing

## Global Constraints

- macOS 15+ deployment target, Swift 6.3, SPM (swift-tools-version 6.2)
- Zero third-party dependencies — pure SwiftUI/AppKit
- Spring parameters: displacement `.spring(response: 0.3, dampingFraction: 0.7)`, drop settle `.spring(response: 0.25, dampingFraction: 0.8)`
- Drag overlay: `scaleEffect(1.15)` + `shadow(radius: 8, y: 4)` + `opacity(0.9)`
- `animateDrag == false` disables all displacement animation (overlay visual feedback preserved)
- Existing `resolveDrop` merge logic (>50% overlap → folder) must remain unchanged
- Cross-page drag and 2×2 enlarged folder occupancy must continue to work

---

## File Structure

| File | Responsibility |
|------|---------------|
| `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift` | Add `liveReorder(draggedID:toIndex:page:)` and `liveReorderInFolder(folderID:appID:toIndex:)` methods; add `gridDragItem`/`gridDragLocation` state for overlay |
| `Sources/InceptLaunch/Views/LaunchpadGridView.swift` | Change ForEach to ID-based identity; modify `directDragGesture` for live reorder; hide dragged tile; add `.animation(value:)` on grid container |
| `Sources/InceptLaunch/Views/FolderPopupView.swift` | Wrap reorder in `withAnimation`; hide dragged member; add `.animation(value:)` on folder grid |
| `Sources/InceptLaunch/Views/ContentView.swift` | Render floating drag overlay at top of ZStack; pass `gridDragLocation` |
| `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift` | Unit tests for `liveReorder` and `liveReorderInFolder` |

---

### Task 1: ViewModel — Add `liveReorder` methods

**Files:**
- Modify: `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift:316-322`
- Test: `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift`

**Interfaces:**
- Consumes: `layoutStore.moveItem(id:toPage:index:)`, `layoutStore.reorderFolderItem(folderID:appID:toIndex:)`, `persistLayout()`
- Produces: `func liveReorder(draggedID: String, toIndex: Int, page: Int)` and `func liveReorderInFolder(folderID: String, appID: String, toIndex: Int)` — called by views during drag `.onChanged`

- [ ] **Step 1: Write failing test for `liveReorder`**

Add to `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift`:

```swift
@MainActor @Test func liveReorderMovesItemWithoutPersisting() {
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
            pages: [[.app(appA.id), .app(appB.id), .app(appC.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace()),
        layoutPersistence: persistence
    )

    viewModel.liveReorder(draggedID: appC.id, toIndex: 0, page: 0)

    let visible = viewModel.visiblePages[0]
    #expect(visible.map(\.id) == [appC.id, appA.id, appB.id])

    // liveReorder must NOT persist (only final drop persists).
    let saved = try? JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: tempURL)
    )
    #expect(saved == nil || saved?.pages[0] != [.app(appC.id), .app(appA.id), .app(appB.id)])
    try? FileManager.default.removeItem(at: tempURL)
}

@MainActor @Test func liveReorderInFolderMovesMember() {
    let appA = makeRecord("Alpha")
    let appB = makeRecord("Beta")
    let appC = makeRecord("Gamma")
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
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.liveReorderInFolder(folderID: "folder:test", appID: appC.id, toIndex: 0)

    let folder = viewModel.visiblePages[0].first(where: { $0.id == "folder:test" })
    #expect(folder?.members.map(\.id) == [appC.id, appA.id, appB.id])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "liveReorder" 2>&1 | tail -20`
Expected: FAIL — `liveReorder` and `liveReorderInFolder` not defined

- [ ] **Step 3: Implement `liveReorder` and `liveReorderInFolder`**

Add to `LaunchpadViewModel.swift` after `moveAppInGrid` (line ~322):

```swift
/// Mid-drag live reorder: moves the item without persisting.
/// Called on every cell-boundary crossing during drag.
func liveReorder(draggedID: String, toIndex: Int, page: Int) {
    layoutStore.moveItem(id: draggedID, toPage: page, index: toIndex)
}

/// Mid-drag live reorder within a folder: moves the member without persisting.
func liveReorderInFolder(folderID: String, appID: String, toIndex: Int) {
    layoutStore.reorderFolderItem(folderID: folderID, appID: appID, toIndex: toIndex)
    refreshOpenFolder()
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter "liveReorder" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Stores/LaunchpadViewModel.swift Tests/InceptLaunchTests/LaunchpadViewModelTests.swift
git commit -m "feat: add liveReorder methods for mid-drag tile displacement"
```

---

### Task 2: Main grid — ID-based ForEach identity

**Files:**
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridView.swift:106-118`

**Interfaces:**
- Consumes: `LaunchpadDisplayItem.id` (stable identity)
- Produces: ForEach with stable identity so SwiftUI can animate position changes in the custom Layout

- [ ] **Step 1: Change ForEach from index-based to ID-based**

In `LaunchpadGridView.swift`, replace the `pageGrid` function body:

```swift
@ViewBuilder
private func pageGrid(_ page: [LaunchpadDisplayItem], iconSize: CGFloat, tileHeight: CGFloat, pageWidth: CGFloat, pageIndex: Int) -> some View {
    LaunchpadGridLayout(
        tileHeight: tileHeight,
        minRows: rows
    ) {
        ForEach(page) { item in
            let idx = page.firstIndex(where: { $0.id == item.id }) ?? 0
            tileCell(item: item, localIndex: idx, iconSize: iconSize, tileHeight: tileHeight, pageWidth: pageWidth, pageIndex: pageIndex)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .padding(.horizontal, 24)
}
```

- [ ] **Step 2: Build to verify no compile errors**

Run: `swift build 2>&1 | tail -5`
Expected: Build complete

- [ ] **Step 3: Run existing tests to verify no regressions**

Run: `swift test 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Sources/InceptLaunch/Views/LaunchpadGridView.swift
git commit -m "refactor: use ID-based ForEach identity for grid animation support"
```

---

### Task 3: Main grid — Live reorder in DragGesture + hide dragged tile

**Files:**
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridView.swift:185-228` (directDragGesture)
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridView.swift:121-182` (tileCell)
- Modify: `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift` (add drag overlay state)

**Interfaces:**
- Consumes: `liveReorder(draggedID:toIndex:page:)` from Task 1, `tileFrames` for hit-testing
- Produces: `onLiveReorder` callback wired from ContentView; `gridDragItem`/`gridDragLocation` on ViewModel for overlay rendering

- [ ] **Step 1: Add drag overlay state to ViewModel**

Add properties to `LaunchpadViewModel.swift` after `floatingDragPoint`:

```swift
/// The item currently being live-reorder-dragged on the main grid (for overlay rendering).
var gridDragItem: LaunchpadDisplayItem?

/// Absolute pointer position in overlay coordinate space during grid drag.
var gridDragLocation: CGPoint = .zero
```

- [ ] **Step 2: Add `onLiveReorder` callback to LaunchpadGridView**

Add property to `LaunchpadGridView`:

```swift
var onLiveReorder: ((String, Int, Int) -> Void)? = nil
```

- [ ] **Step 3: Modify `directDragGesture` for live reorder**

Replace `directDragGesture` in `LaunchpadGridView.swift`:

```swift
private func directDragGesture(
    item: LaunchpadDisplayItem,
    localIndex: Int,
    pageWidth: CGFloat,
    pageIndex: Int
) -> some Gesture {
    DragGesture(minimumDistance: 6, coordinateSpace: .named("overlay"))
        .onChanged { value in
            isDraggingTile = true
            let translation = CGSize(
                width: value.translation.width + dragPageOffset,
                height: value.translation.height
            )
            maybeFlipPageAtEdge(fingerX: value.location.x, pageWidth: pageWidth)

            // Live reorder: compute target index from pointer position.
            if animateDrag, let onLiveReorder {
                let targetIndex = computeGridTargetIndex(
                    dragID: item.id,
                    location: value.location,
                    page: currentPage
                )
                let currentIndex = pages[currentPage].firstIndex(where: { $0.id == item.id }) ?? localIndex
                if targetIndex != currentIndex {
                    onLiveReorder(item.id, targetIndex, currentPage)
                }
            }

            NotificationCenter.default.post(
                name: .inceptLaunchEditDragChanged,
                object: EditDragUpdate(id: item.id, translation: translation)
            )
            NotificationCenter.default.post(
                name: .inceptLaunchGridDragMoved,
                object: GridDragLocationUpdate(id: item.id, location: value.location)
            )
        }
        .onEnded { value in
            defer {
                isDraggingTile = false
                dragPageOffset = 0
                NotificationCenter.default.post(name: .inceptLaunchEditDragEnded, object: nil)
                NotificationCenter.default.post(name: .inceptLaunchGridDragEnded, object: nil)
            }

            let translation = CGSize(
                width: value.translation.width + dragPageOffset,
                height: value.translation.height
            )

            if let onResolveDrop {
                onResolveDrop(item.id, value.location, translation, currentPage, localIndex)
                return
            }

            if currentPage != pageIndex || translation != .zero {
                onMoveApp?(item.id, currentPage, localIndex)
            }
        }
}
```

- [ ] **Step 4: Add `computeGridTargetIndex` helper**

Add to `LaunchpadGridView.swift`:

```swift
private func computeGridTargetIndex(dragID: String, location: CGPoint, page: Int) -> Int {
    let pageItems = pages[page]
    let otherFrames = tileFrames
        .filter { $0.id != dragID && pageItems.contains(where: { $0.id == $0.id }) }
        .sorted { frame in
            let item = pageItems.firstIndex(where: { $0.id == frame.id }) ?? 0
            return item
        }

    for (rank, info) in otherFrames.enumerated() {
        if location.x < info.frame.midX && location.y < info.frame.maxY {
            return rank
        }
    }
    return pageItems.count - 1
}
```

- [ ] **Step 5: Add notification types for grid drag location**

Add to `LaunchpadGridView.swift` (near existing `EditDragUpdate`):

```swift
struct GridDragLocationUpdate {
    let id: String
    let location: CGPoint
}

extension Notification.Name {
    static let inceptLaunchGridDragMoved = Notification.Name("inceptLaunchGridDragMoved")
    static let inceptLaunchGridDragEnded = Notification.Name("inceptLaunchGridDragEnded")
}
```

- [ ] **Step 6: Hide dragged tile in `tileCell`**

In `tileCell`, change the opacity line inside the `TimelineView` closure. Replace:

```swift
.opacity(isBeingDragged ? 0.92 : 1.0)
```

with:

```swift
.opacity(isBeingDragged && animateDrag ? 0.0 : (isBeingDragged ? 0.92 : 1.0))
```

This hides the tile in the grid when live-reorder animation is active (the overlay replaces it visually).

- [ ] **Step 7: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build complete

- [ ] **Step 8: Commit**

```bash
git add Sources/InceptLaunch/Views/LaunchpadGridView.swift Sources/InceptLaunch/Stores/LaunchpadViewModel.swift
git commit -m "feat: live reorder in main grid drag gesture with tile hiding"
```

---

### Task 4: ContentView — Render floating drag overlay

**Files:**
- Modify: `Sources/InceptLaunch/Views/ContentView.swift:20-133`

**Interfaces:**
- Consumes: `viewModel.gridDragItem`, `viewModel.gridDragLocation`, `GridDragLocationUpdate` notification
- Produces: A floating tile overlay at the top of the ZStack that follows the pointer during grid drag

- [ ] **Step 1: Add notification receivers for grid drag location**

Add after the existing `.onReceive(.inceptLaunchEditDragEnded)` block in `ContentView.swift`:

```swift
.onReceive(NotificationCenter.default.publisher(for: .inceptLaunchGridDragMoved)) { note in
    if let update = note.object as? GridDragLocationUpdate {
        if viewModel.gridDragItem == nil {
            viewModel.gridDragItem = viewModel.visiblePages
                .flatMap { $0 }
                .first(where: { $0.id == update.id })
        }
        viewModel.gridDragLocation = update.location
    }
}
.onReceive(NotificationCenter.default.publisher(for: .inceptLaunchGridDragEnded)) { _ in
    viewModel.gridDragItem = nil
    viewModel.gridDragLocation = .zero
}
```

- [ ] **Step 2: Render the floating overlay in the ZStack**

Add after the `FolderPopupView` block (before the closing `}` of the ZStack), at `zIndex(3)`:

```swift
if let dragItem = viewModel.gridDragItem {
    AppIconView(
        item: dragItem,
        iconSize: GridMetrics.iconSize,
        tileHeight: GridMetrics.tileHeight
    )
    .scaleEffect(1.15)
    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    .opacity(0.9)
    .position(viewModel.gridDragLocation)
    .allowsHitTesting(false)
    .zIndex(3)
}
```

- [ ] **Step 3: Wire `onLiveReorder` callback in `contentBody`**

In the `LaunchpadGridView(...)` initializer call, add:

```swift
onLiveReorder: { draggedID, toIndex, page in
    if animEnabled && preferences.animateDrag {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.liveReorder(draggedID: draggedID, toIndex: toIndex, page: page)
        }
    } else {
        viewModel.liveReorder(draggedID: draggedID, toIndex: toIndex, page: page)
    }
},
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build complete

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Views/ContentView.swift
git commit -m "feat: render floating drag overlay during grid live reorder"
```

---

### Task 5: Main grid — Add `.animation(value:)` for non-drag reorder animation

**Files:**
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridView.swift:106-118`

**Interfaces:**
- Consumes: `pages` array (item order as animation trigger)
- Produces: Implicit spring animation on tile positions when page content changes (deletion, tidy, etc.)

- [ ] **Step 1: Add animation modifier to the grid container**

In `pageGrid`, add `.animation` after `.padding(.horizontal, 24)`:

```swift
@ViewBuilder
private func pageGrid(_ page: [LaunchpadDisplayItem], iconSize: CGFloat, tileHeight: CGFloat, pageWidth: CGFloat, pageIndex: Int) -> some View {
    LaunchpadGridLayout(
        tileHeight: tileHeight,
        minRows: rows
    ) {
        ForEach(page) { item in
            let idx = page.firstIndex(where: { $0.id == item.id }) ?? 0
            tileCell(item: item, localIndex: idx, iconSize: iconSize, tileHeight: tileHeight, pageWidth: pageWidth, pageIndex: pageIndex)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .padding(.horizontal, 24)
    .animation(
        animateDrag ? .spring(response: 0.3, dampingFraction: 0.7) : nil,
        value: page.map(\.id)
    )
}
```

- [ ] **Step 2: Build and run tests**

Run: `swift build 2>&1 | tail -5 && swift test 2>&1 | tail -10`
Expected: Build complete, all tests pass

- [ ] **Step 3: Commit**

```bash
git add Sources/InceptLaunch/Views/LaunchpadGridView.swift
git commit -m "feat: add implicit spring animation on grid tile position changes"
```

---

### Task 6: Folder interior — Animated live reorder

**Files:**
- Modify: `Sources/InceptLaunch/Views/FolderPopupView.swift:121-170` (drag gesture)
- Modify: `Sources/InceptLaunch/Views/FolderPopupView.swift:56-65` (LazyVGrid)
- Modify: `Sources/InceptLaunch/Views/ContentView.swift:81-86` (onReorder callback)

**Interfaces:**
- Consumes: `liveReorderInFolder(folderID:appID:toIndex:)` from Task 1
- Produces: Animated tile displacement inside folder popup during drag

- [ ] **Step 1: Add `.animation(value:)` to folder LazyVGrid**

In `FolderPopupView.swift`, add after `.padding(.bottom, 26)` on the LazyVGrid:

```swift
.animation(
    animate ? .spring(response: 0.3, dampingFraction: 0.7) : nil,
    value: item.members.map(\.id)
)
```

- [ ] **Step 2: Hide dragged member tile during reorder**

In `folderMemberCell`, change the opacity line inside the `TimelineView`:

```swift
.opacity(leftFolder && editDragID == member.id ? 0 : (reorderDragID == member.id && animate ? 0 : 1))
```

- [ ] **Step 3: Add folder drag overlay in FolderPopupView's ZStack**

Add a `@State` for folder drag location:

```swift
@State private var folderDragLocation: CGPoint = .zero
```

In the drag gesture `.onChanged`, after `reorderDragID = member.id`, add:

```swift
folderDragLocation = value.location
```

Add overlay rendering inside the outer `ZStack` (after the VStack, before the closing `}`):

```swift
if let dragID = reorderDragID,
   let dragMember = item.members.first(where: { $0.id == dragID }),
   animate {
    AppIconView(
        item: LaunchpadDisplayItem(id: dragMember.id, title: dragMember.name, kind: .app(dragMember)),
        iconSize: 88,
        tileHeight: 128
    )
    .scaleEffect(1.15)
    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    .opacity(0.9)
    .position(folderDragLocation)
    .allowsHitTesting(false)
    .zIndex(10)
}
```

- [ ] **Step 4: Wire `onReorder` with animation in ContentView**

In `ContentView.swift`, replace the `onReorder` closure:

```swift
onReorder: { appID, newIndex in
    if case .folder(let f) = folder.kind {
        if animEnabled && preferences.animateDrag {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.liveReorderInFolder(folderID: f.id, appID: appID, toIndex: newIndex)
            }
        } else {
            viewModel.liveReorderInFolder(folderID: f.id, appID: appID, toIndex: newIndex)
        }
    }
}
```

- [ ] **Step 5: Clear folder drag overlay on drop**

In the drag gesture `.onEnded`, after `reorderDragID = nil`, add:

```swift
folderDragLocation = .zero
```

- [ ] **Step 6: Build and run tests**

Run: `swift build 2>&1 | tail -5 && swift test 2>&1 | tail -10`
Expected: Build complete, all tests pass

- [ ] **Step 7: Commit**

```bash
git add Sources/InceptLaunch/Views/FolderPopupView.swift Sources/InceptLaunch/Views/ContentView.swift
git commit -m "feat: animated live reorder inside folder popup"
```

---

### Task 7: Persist on drop + drag cancellation rollback

**Files:**
- Modify: `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift` (resolveDrop, clearFloatingDrag)
- Modify: `Sources/InceptLaunch/Views/LaunchpadGridView.swift` (onEnded)

**Interfaces:**
- Consumes: `liveReorder` (already mutated model), `persistLayout()`
- Produces: Layout persisted on successful drop; rollback on cancel

- [ ] **Step 1: Add `persistLayout` call after `resolveDrop` completes**

The existing `resolveDrop` already calls `persistLayout()` via `moveAppInGrid` and `handleDrop`. Since `liveReorder` already moved the item in the model, `resolveDrop`'s `moveAppInGrid` call will be a no-op move to the same position (or a merge). Verify this is correct — no additional persist needed for the reorder-only path.

Add a `persistLayout()` call at the end of the reorder-only branch in `resolveDrop` (after `moveAppInGrid`):

In `resolveDrop`, the existing code already calls `moveAppInGrid` which calls `persistLayout()`. No change needed here.

- [ ] **Step 2: Add drag cancellation support**

Add to `LaunchpadViewModel.swift`:

```swift
/// Original position before live reorder began (for rollback on cancel).
private var preReorderPage: [LaunchpadItem] = []
private var preReorderDragID: String?

func beginLiveReorder(draggedID: String, page: Int) {
    guard preReorderDragID == nil else { return }
    preReorderDragID = draggedID
    if layoutStore.layout.pages.indices.contains(page) {
        preReorderPage = layoutStore.layout.pages[page]
    }
}

func cancelLiveReorder(page: Int) {
    guard let dragID = preReorderDragID else { return }
    if layoutStore.layout.pages.indices.contains(page) {
        layoutStore.layout.pages[page] = preReorderPage
    }
    preReorderDragID = nil
    preReorderPage = []
}

func endLiveReorder() {
    preReorderDragID = nil
    preReorderPage = []
    persistLayout()
}
```

- [ ] **Step 3: Call `beginLiveReorder` on first reorder, `endLiveReorder` on drop**

In `ContentView.swift`'s `onLiveReorder` closure, add at the start:

```swift
viewModel.beginLiveReorder(draggedID: draggedID, page: page)
```

In the `.onReceive(.inceptLaunchGridDragEnded)` handler, add:

```swift
viewModel.endLiveReorder()
```

- [ ] **Step 4: Write test for cancellation rollback**

Add to `LaunchpadViewModelTests.swift`:

```swift
@MainActor @Test func cancelLiveReorderRestoresOriginalOrder() {
    let appA = makeRecord("Alpha")
    let appB = makeRecord("Beta")
    let appC = makeRecord("Gamma")
    let viewModel = LaunchpadViewModel(
        appIndex: AppIndexStore(records: [
            appA.id: appA, appB.id: appB, appC.id: appC
        ]),
        layoutStore: LayoutStore(layout: .init(
            pages: [[.app(appA.id), .app(appB.id), .app(appC.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )),
        matcher: SearchMatcher(),
        launcher: AppLauncher(workspace: MockWorkspace())
    )

    viewModel.beginLiveReorder(draggedID: appC.id, page: 0)
    viewModel.liveReorder(draggedID: appC.id, toIndex: 0, page: 0)
    #expect(viewModel.visiblePages[0].map(\.id) == [appC.id, appA.id, appB.id])

    viewModel.cancelLiveReorder(page: 0)
    #expect(viewModel.visiblePages[0].map(\.id) == [appA.id, appB.id, appC.id])
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter "cancelLiveReorder" 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/InceptLaunch/Stores/LaunchpadViewModel.swift Sources/InceptLaunch/Views/ContentView.swift Tests/InceptLaunchTests/LaunchpadViewModelTests.swift
git commit -m "feat: persist on drop and rollback on drag cancellation"
```

---

### Task 8: Manual verification and edge-case testing

**Files:**
- No code changes — verification only

- [ ] **Step 1: Build and launch the app**

Run: `swift build && .build/debug/InceptLaunch`

- [ ] **Step 2: Test main grid live reorder**

1. Open the Launchpad overlay
2. Long-press a tile to enter edit mode
3. Drag an app across several tiles — verify they spring-animate out of the way
4. Drop the app — verify it settles into position
5. Drag again and press Esc mid-drag — verify rollback to original position

- [ ] **Step 3: Test folder interior reorder**

1. Open a folder
2. Drag an app within the folder — verify other members animate aside
3. Drop — verify final position is correct

- [ ] **Step 4: Test `animateDrag` toggle**

1. Open Settings, disable "拖拽动画"
2. Drag an app — verify no displacement animation (instant snap) but overlay scale/shadow still visible
3. Re-enable — verify animation returns

- [ ] **Step 5: Test cross-page drag**

1. Drag an app to the left/right edge — verify page flip still works
2. After flip, verify live reorder continues on the new page

- [ ] **Step 6: Test folder merge (>50% overlap)**

1. Drag an app onto another app with >50% overlap — verify folder creation still works (no displacement triggered)

- [ ] **Step 7: Test 2×2 enlarged folder**

1. Enlarge a folder (context menu)
2. Drag an app near it — verify displacement skips the 4-cell area correctly

- [ ] **Step 8: Commit final state if any fixes were needed**

```bash
git add -A
git commit -m "fix: edge-case fixes for reorder animation"
```
