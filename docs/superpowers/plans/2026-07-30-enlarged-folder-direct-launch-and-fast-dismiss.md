# Enlarged-folder direct launch + fast dismiss Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users launch apps by tapping mini icons on 2×2 enlarged folder tiles, and dismiss the fullscreen overlay immediately before any app open so launch no longer freezes for 2–5 seconds.

**Architecture:** Add per-member tap handlers on `EnlargedFolderTileView` (visible carousel page only). Wire them through `LaunchpadGridView` to a shared `ContentView.launchAndDismiss(_:)` helper that posts dismiss first, then launches on the next main-queue turn. Keep `AppLauncher.launch` synchronous for tests; UI never waits on it before hide.

**Tech Stack:** SwiftUI + AppKit, Swift Testing, existing `AppLauncher` / `Notification.Name.iLaunchDismiss`.

**Spec:** `docs/superpowers/specs/2026-07-30-enlarged-folder-direct-launch-and-fast-dismiss-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `Sources/iLaunch/Views/EnlargedFolderTileView.swift` | Mini-icon hit targets + `onActivateMember` callback |
| `Sources/iLaunch/Views/LaunchpadGridView.swift` | Wire `onLaunchApp` from enlarged folder members; edit-mode gate |
| `Sources/iLaunch/Views/ContentView.swift` | `launchAndDismiss(record)` used by grid, search, popup, mini icons |
| `script/build_and_run.sh` | Patch version bump after feature (1.7.12 → 1.7.13) |

No model or persistence changes. `AppLauncher.swift` stays as-is unless a tiny helper is cleaner; plan uses dismiss-first + `DispatchQueue.main.async` around existing `launch`.

---

### Task 1: Fast dismiss — shared `launchAndDismiss` in ContentView

**Files:**
- Modify: `Sources/iLaunch/Views/ContentView.swift`
- Test: manual / existing `AppLauncherTests` unchanged

- [ ] **Step 1: Add `launchAndDismiss` and switch all app-launch call sites**

In `ContentView.swift`, replace the three launch paths with one helper.

Current folder popup (≈ lines 48–51):

```swift
onLaunch: { record in
    _ = AppLauncher().launch(record)
    viewModel.openFolder = nil
    dismiss()
},
```

Current `handleTap` (≈ lines 362–369):

```swift
private func handleTap(_ item: LaunchpadDisplayItem) {
    switch item.kind {
    case .app(let record):
        _ = AppLauncher().launch(record)
        dismiss()
    case .folder:
        viewModel.openFolder = item
    }
}
```

Replace with:

```swift
/// Dismiss the overlay first, then open the app on the next main turn.
/// Synchronous `NSWorkspace.open` must never block hide (cold start 2–5s).
private func launchAndDismiss(_ record: AppRecord) {
    viewModel.openFolder = nil
    dismiss()
    DispatchQueue.main.async {
        _ = AppLauncher().launch(record)
    }
}

private func handleTap(_ item: LaunchpadDisplayItem) {
    switch item.kind {
    case .app(let record):
        launchAndDismiss(record)
    case .folder:
        viewModel.openFolder = item
    }
}
```

And folder popup:

```swift
onLaunch: { record in
    launchAndDismiss(record)
},
```

Search results already go through `handleTap` via `onLaunch: { item in handleTap(item) }` — no extra change.

- [ ] **Step 2: Build to verify compile**

Run:

```bash
cd /Users/xiaoan/Documents/code/iLaunch && swift build 2>&1
```

Expected: build succeeds (exit 0).

- [ ] **Step 3: Commit**

```bash
git add Sources/iLaunch/Views/ContentView.swift
git commit -m "fix: dismiss overlay before launching apps to remove launch lag"
```

---

### Task 2: Mini-icon activate on EnlargedFolderTileView

**Files:**
- Modify: `Sources/iLaunch/Views/EnlargedFolderTileView.swift`

- [ ] **Step 1: Add `onActivateMember` and per-icon taps**

Add property after `showName`:

```swift
var showName: Bool = true
/// When set, tapping a mini member icon invokes this instead of bubbling to the parent chrome tap (open folder).
var onActivateMember: ((AppRecord) -> Void)? = nil
```

Update `carouselContent` so only the visible page receives hits:

```swift
ForEach(0..<pageCount, id: \.self) { page in
    let start = page * 9
    let slice = Array(members.dropFirst(start).prefix(9))
    iconGrid(members: slice)
        .opacity(page == carouselPage ? 1 : 0)
        .allowsHitTesting(page == carouselPage)
}
```

Update `iconGrid` so filled cells are tappable when callback is set:

```swift
private func iconGrid(members: [AppRecord]) -> some View {
    let spacing: CGFloat = 8
    return Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
        ForEach(0..<3, id: \.self) { row in
            GridRow {
                ForEach(0..<3, id: \.self) { col in
                    let index = row * 3 + col
                    if index < members.count {
                        let record = members[index]
                        RealAppIcon(record: record)
                            .frame(width: miniIconSize, height: miniIconSize)
                            .contentShape(Rectangle())
                            .modifier(EnlargedMemberTapModifier(
                                record: record,
                                onActivateMember: onActivateMember
                            ))
                    } else {
                        Color.clear.frame(width: miniIconSize, height: miniIconSize)
                    }
                }
            }
        }
    }
}
```

Add at file bottom (private helper so empty handler does not install a gesture that steals parent taps incorrectly when nil — only attach when non-nil):

```swift
/// High-priority tap on a mini icon so parent chrome `.onTapGesture` (open folder) does not fire.
private struct EnlargedMemberTapModifier: ViewModifier {
    let record: AppRecord
    var onActivateMember: ((AppRecord) -> Void)?

    func body(content: Content) -> some View {
        if let onActivateMember {
            content.highPriorityGesture(
                TapGesture().onEnded { onActivateMember(record) }
            )
        } else {
            content
        }
    }
}
```

Notes:
- Empty cells keep no gesture → chrome parent tap still opens folder.
- `highPriorityGesture(TapGesture)` beats the parent `onTapGesture` on the same chrome.
- Drag for folder reorder still uses outer `DragGesture(minimumDistance: 6)` on the parent; mini taps use zero-distance tap only.

- [ ] **Step 2: Build**

```bash
cd /Users/xiaoan/Documents/code/iLaunch && swift build 2>&1
```

Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Sources/iLaunch/Views/EnlargedFolderTileView.swift
git commit -m "feat: allow tapping mini icons on enlarged folder tiles"
```

---

### Task 3: Wire grid callback through LaunchpadGridView → ContentView

**Files:**
- Modify: `Sources/iLaunch/Views/LaunchpadGridView.swift`
- Modify: `Sources/iLaunch/Views/ContentView.swift`

- [ ] **Step 1: Add `onLaunchApp` to LaunchpadGridView**

After `onLaunch` property (line 8):

```swift
let onLaunch: (LaunchpadDisplayItem) -> Void
/// Direct app launch from enlarged-folder mini icons (skips open-folder).
var onLaunchApp: ((AppRecord) -> Void)? = nil
```

In `tileView` for enlarged folders, pass the callback and gate edit mode:

```swift
EnlargedFolderTileView(
    item: item,
    tileWidth: tileWidth,
    tileHeight: tileHeight,
    iconSize: iconSize,
    showName: showAppNames,
    onActivateMember: { record in
        if editMode {
            onCancelEditMode?()
        } else {
            onLaunchApp?(record)
        }
    }
)
.onTapGesture {
    if editMode {
        onCancelEditMode?()
    } else {
        onLaunch(item)
    }
}
// ... keep long-press + drag as today
```

- [ ] **Step 2: Wire ContentView**

In both `LaunchpadGridView(...)` constructions if there are two (search uses `SearchResultsView` only — one grid instance around line 199):

```swift
LaunchpadGridView(
    pages: viewModel.visiblePages,
    rows: viewModel.gridRows,
    columns: viewModel.gridColumns,
    enlargedFolderIDs: viewModel.enlargedFolderIDs,
    onLaunch: { item in handleTap(item) },
    onLaunchApp: { record in launchAndDismiss(record) },
    // ... rest unchanged
```

If the memberwise init fails because `onLaunchApp` is not the next labeled arg position: `onLaunchApp` is a `var` with default `nil` after required `let`s — in Swift, defaulted properties can be passed by name after required ones. Place it immediately after `onLaunch:` for readability.

- [ ] **Step 3: Build + test**

```bash
cd /Users/xiaoan/Documents/code/iLaunch && swift build 2>&1 && swift test 2>&1
```

Expected: build and tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/iLaunch/Views/LaunchpadGridView.swift Sources/iLaunch/Views/ContentView.swift
git commit -m "feat: wire enlarged-folder mini icon launch to dismiss path"
```

---

### Task 4: Version bump, package, verify

**Files:**
- Modify: `script/build_and_run.sh` (patch 1.7.12 → 1.7.13)

- [ ] **Step 1: Bump version**

In `script/build_and_run.sh`, set both:

```xml
<key>CFBundleShortVersionString</key>
<string>1.7.13</string>
<key>CFBundleVersion</key>
<string>1.7.13</string>
```

- [ ] **Step 2: Build & run package**

```bash
cd /Users/xiaoan/Documents/code/iLaunch/script && bash build_and_run.sh run
```

Expected: compiles, assembles `.app`, codesigns, launches.

- [ ] **Step 3: Manual smoke checklist**

1. Enlarge a folder (context menu / enlarge) with ≥2 apps.
2. Click a specific mini icon → that app opens; overlay gone immediately (no multi-second freeze).
3. Click folder title / empty chrome → popup opens.
4. Multi-page enlarged folder: only current page icons launch; chevrons still work.
5. Normal grid app: overlay dismisses immediately.
6. Folder popup member: same fast dismiss.

- [ ] **Step 4: Commit version bump**

```bash
git add script/build_and_run.sh
git commit -m "chore: bump version to 1.7.13"
```

(If preferred, fold version bump into the last feature commit instead — either is fine per project history.)

---

## Spec coverage self-check

| Spec requirement | Task |
|------------------|------|
| Mini-icon direct launch on enlarged folder | Task 2–3 |
| Chrome / empty still opens popup | Task 2 (no gesture on empty) + Task 3 chrome `onTapGesture` |
| Edit mode does not launch | Task 3 gate |
| Carousel only current page hittable | Task 2 `allowsHitTesting` |
| Fast dismiss before open (all paths) | Task 1 |
| Version bump + package | Task 4 |
| Out of scope: small FolderTileView | Not touched |

## Placeholder scan

No TBD / TODO / “implement later” left in tasks.

## Type consistency

- `onActivateMember: ((AppRecord) -> Void)?`
- `onLaunchApp: ((AppRecord) -> Void)?`
- `launchAndDismiss(_ record: AppRecord)`
