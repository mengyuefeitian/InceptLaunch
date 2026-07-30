# Enlarged-folder direct app launch + fast overlay dismiss

## Objective

Two related UX fixes for InceptLaunch:

1. **Direct launch from enlarged folder previews** — On a 2×2 enlarged folder tile (not the full-screen folder popup), the user can click an individual mini app icon and launch that app immediately, without first opening the folder popup.
2. **Fast dismiss on app launch** — Clicking any app currently freezes the fullscreen overlay for ~2–5 seconds before it exits. The overlay must dismiss immediately; app launch must not block that dismiss.

## Background / root cause

### Enlarged folder (feature)

- `EnlargedFolderTileView` draws a 3×3 (or carousel of 3×3) of member icons.
- `LaunchpadGridView.tileView` attaches a single `.onTapGesture` on the whole chrome that calls `onLaunch(folderItem)`.
- `ContentView.handleTap` treats folders as “open popup” (`viewModel.openFolder = item`).
- Mini icons are pure visuals (`RealAppIcon`); they have no independent hit target.

### Launch lag (bug)

Call sites (grid + folder popup) currently do:

```text
AppLauncher.launch(record)   // sync NSWorkspace.shared.open(url) — can block 2–5s on cold start
dismiss()                    // only after open returns
```

`SystemWorkspaceLauncher` uses synchronous `NSWorkspace.shared.open(url)`. While it blocks, the overlay stays visible. That is the root cause of the lag, not SwiftUI animation or layout.

## Design

### 1. Enlarged-folder mini-icon hit targets

**Scope:** only `EnlargedFolderTileView` (2×2 enlarged grid tile). Out of scope: small 1×1 `FolderTileView` previews, and `FolderPopupView` (already launches members).

**Interaction**

| Click target | Behavior |
|--------------|----------|
| Mini member icon (visible cell on current carousel page) | Launch that `AppRecord` (same path as launching a normal app tile) |
| Empty cell / padding / title / chrome outside mini icons | Open folder popup (current whole-tile behavior) |
| Edit mode | Unchanged: tap cancels edit mode via existing handlers; do not launch |
| Long-press / drag on chrome | Unchanged: enter edit / drag folder |

**Implementation sketch**

- Add optional callbacks to `EnlargedFolderTileView`:
  - `onActivateMember: ((AppRecord) -> Void)?`
  - `onActivateFolder: (() -> Void)?` (or keep parent-owned whole-chrome open as today)
- In `iconGrid`, each filled cell gets `.contentShape(Rectangle())` + `onTapGesture` that calls `onActivateMember(record)` and stops the event from also opening the folder (child gesture wins over parent; if needed use `highPriorityGesture` on the mini icon).
- Parent `LaunchpadGridView` for enlarged folders:
  - Wire `onActivateMember` → new grid callback `onLaunchApp: (AppRecord) -> Void` (or reuse a dedicated path) that reaches `ContentView` launch+dismiss.
  - Keep chrome-level tap → `onLaunch(folderItem)` for open-popup.
- Carousel: only the **visible** page’s icons are hittable (hidden pages use `opacity: 0` and should use `.allowsHitTesting(page == carouselPage)` so invisible icons never steal hits).
- Auto-advance timer / page chevrons unchanged.

### 2. Fast dismiss before launch

**Invariant:** every user-initiated app launch from the overlay must:

1. Request overlay hide **first** (same frame / before any blocking work).
2. Then start the app open (non-blocking relative to UI).

**Preferred API change**

- Keep `AppLauncher.launch(_:)` for tests and simple sync open of path checks.
- Add a non-blocking path used by UI:

```swift
// Conceptual
func launchAsync(_ record: AppRecord) {
  // path existence check stays cheap/sync
  // then NSWorkspace.shared.openApplication(at:configuration:completionHandler:)
  // or: DispatchQueue.main.async { workspace.open(...) } after dismiss already posted
}
```

Minimum viable fix (acceptable if async workspace API is awkward to mock):

```swift
// ContentView / popup onLaunch
dismiss()                          // post .inceptLaunchDismiss immediately
DispatchQueue.main.async {
  _ = AppLauncher().launch(record) // open after hide has started
}
```

**Order of operations (all call sites)**

1. Clear any folder popup state if needed (`openFolder = nil` can be in the same turn as dismiss; hide already clears UI).
2. `dismiss()` → `OverlayWindowController.hide()` (orderOut + `NSApp.hide`).
3. Launch app.

**Call sites to unify**

- `ContentView.handleTap` (grid / search results apps)
- `ContentView` `FolderPopupView.onLaunch`
- New enlarged-folder mini-icon path

**Do not** wait for `LaunchResult` before dismissing. Failed launches after hide are acceptable (same as weak feedback today).

Optional hardening: move `NSWorkspace.shared.open` off the critical path with `openApplication(at:configuration:completionHandler:)` so even post-dismiss main-thread work stays light. Tests keep using the sync protocol.

### 3. Data flow

```text
EnlargedFolderTileView mini icon tap
  → LaunchpadGridView onLaunchApp(record)
  → ContentView.launchAndDismiss(record)
       1. dismiss()  → OverlayWindowController.hide()
       2. async AppLauncher.launch(record)

Normal app tile / search result
  → handleTap(.app) → launchAndDismiss(record)  // same helper

FolderPopupView member
  → onLaunch(record) → launchAndDismiss(record)  // same helper
```

### 4. Error handling

- Missing path: still return `.missingPath` from sync launcher; UI does not re-show overlay.
- Open failure: no new UI; log via `DiagLog` if useful.
- Edit mode: mini-icon tap must not launch (mirror grid: cancel edit or ignore launch while jiggling — prefer same as parent: `if editMode { onCancelEditMode } else { launch }`).

### 5. Testing

**Unit**

- `AppLauncher` path-missing behavior unchanged.
- If a small pure helper is extracted for “launch after dismiss” ordering, test is optional; ordering is integration-sensitive.
- Prefer a focused test only if launch orchestration moves into `LaunchpadViewModel` (e.g. `launchAndDismiss` records call order with a mock). Recommended: add `LaunchpadViewModel.launchAppAndRequestDismiss` or keep orchestration in `ContentView` and rely on manual/build verification for order.

**Manual / build**

1. Enlarge a folder with ≥2 apps → click a specific mini icon → that app starts; overlay gone immediately.
2. Click chrome title / empty cell → folder popup opens (no app launch).
3. Multi-page enlarged folder: only current page icons launch; swipe/chevrons still work.
4. Normal grid app click: overlay dismisses immediately even for cold-start heavy apps.
5. Folder popup member click: same fast dismiss.
6. Edit mode: long-press then tap does not launch incorrectly.

### 6. Files likely touched

| File | Change |
|------|--------|
| `Views/EnlargedFolderTileView.swift` | Per-icon activate + hit testing for current carousel page |
| `Views/LaunchpadGridView.swift` | Wire member callback; edit-mode gate |
| `Views/ContentView.swift` | Shared `launchAndDismiss`; wire new callback |
| `Services/AppLauncher.swift` | Optional async/open API; keep sync for tests |
| Tests (optional) | Launch order / mock if logic moves to VM |

### 7. Out of scope

- Direct launch from small (1×1) closed `FolderTileView` 9-icon preview
- Changing folder popup layout or drag-out
- Launch failure toasts / retry UI
- Performance work beyond removing blocking open-before-dismiss

## Success criteria

- [ ] Enlarged folder: precise mini-icon click launches that app without opening the popup.
- [ ] Enlarged folder: non-icon chrome still opens the popup.
- [ ] Any app launch dismisses the overlay immediately (perceived lag ≪ 1s for hide).
- [ ] Build + package succeeds after version bump per `AGENT.md`.
