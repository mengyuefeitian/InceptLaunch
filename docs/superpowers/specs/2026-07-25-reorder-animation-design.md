# Reorder Animation Design — Real-time Tile Displacement

## Overview

Implement iOS-style real-time "make way" animation for app tile reordering in InceptLaunch. When dragging an app over other tiles, they spring-animate out of the way in real time (before drop). Applies to both the main Launchpad grid and folder interiors.

## Approach

**Live model reorder + implicit animation**: During drag, when the pointer enters a new grid cell, immediately mutate the data model inside `withAnimation(.spring(...))`. SwiftUI animates the Layout position changes automatically. The dragged tile is "lifted" as an overlay following the pointer; the original slot is hidden.

## Trigger Mechanism

- Based on nearest grid cell: when the drag center enters a cell, that cell's occupant and subsequent items shift back by one position.
- Throttle: only trigger when target index differs from current index.

## Animation Style

- Spring: `.spring(response: 0.3, dampingFraction: 0.7)` for displacement.
- Drop settle: `.spring(response: 0.25, dampingFraction: 0.8)`.
- Draggable overlay: `scaleEffect(1.15)` + `shadow(radius: 8, y: 4)` + `opacity(0.9)`.

## Main Grid (LaunchpadGridView)

### DragGesture changes

- `.onChanged`:
  1. Update overlay position (follow pointer).
  2. Compute pointer center grid index via `GridMetrics`.
  3. If index != current item index, call `liveReorder(draggedID:toIndex:page:)`.
  4. On first `.onChanged`, set `isDragging = true`, hide original tile.

- `.onEnded`:
  1. Run existing `resolveDrop` logic (folder merge vs. final placement).
  2. Animate overlay back to target cell.
  3. Remove overlay, restore tile visibility.

### ViewModel additions

```swift
func liveReorder(draggedID: String, toIndex: Int, page: Int) {
    guard animateDrag else {
        layoutStore.moveItem(id: draggedID, toPage: page, index: toIndex)
        return
    }
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        layoutStore.moveItem(id: draggedID, toPage: page, index: toIndex)
    }
}
```

### Grid animation modifier

```swift
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: pageItemIDs)
```

Where `pageItemIDs` is the current page's item ID array, ensuring animation triggers on any order change (including non-drag scenarios like app deletion).

### Overlay layer

A conditionally-rendered drag overlay at the top of `ContentView`'s ZStack, positioned by `@State var dragLocation: CGPoint`.

## Folder Interior (FolderPopupView)

### DragGesture changes

Same pattern as main grid:

- `.onChanged`: update overlay, compute target via existing `computeReorderIndex()`, call `liveReorderInFolder` on index change, hide original tile.
- `.onEnded`: animate overlay to target, remove overlay, restore tile.

### ViewModel additions

```swift
func liveReorderInFolder(folderID: String, appID: String, toIndex: Int) {
    guard animateDrag else {
        layoutStore.reorderFolderItem(folderID: folderID, appID: appID, toIndex: toIndex)
        return
    }
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        layoutStore.reorderFolderItem(folderID: folderID, appID: appID, toIndex: toIndex)
    }
}
```

### Folder grid animation modifier

```swift
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: folderItemIDs)
```

### Overlay layer

Rendered within `FolderPopupView`'s own ZStack, using the existing `"overlay"` named coordinate space.

## Edge Cases

### Cross-page drag
- Existing page-flip logic at grid edges remains unchanged.
- `liveReorder` page parameter follows current page; item is removed from original page and inserted into new page.

### 2x2 enlarged folder tiles
- Target index computation reuses existing `LaunchpadGridLayout` occupancy map logic.
- Enlarged folders move as a unit; other items skip the 4 cells they occupy.

### Drop onto folder (merge)
- Real-time displacement only triggers for non-folder targets.
- If hovering over a folder tile with >50% overlap, existing merge logic applies; no displacement triggered.

### Drag cancellation
- On cancel (Esc or drag out of valid area), `withAnimation` moves item back to original index.

### `animateDrag == false`
- All `withAnimation` calls replaced with no-animation transactions.
- Drag overlay scale/shadow visual feedback is preserved (it's visual affordance, not displacement animation).

## Performance

- `liveReorder` only fires on index change, not every frame.
- Spring animations are driven by SwiftUI's render server, not blocking main-thread logic.

## Files Changed

| File | Change |
|------|--------|
| `LaunchpadViewModel.swift` | Add `liveReorder`, `liveReorderInFolder`, drag state management |
| `LaunchpadGridView.swift` | DragGesture `.onChanged` live reorder, overlay rendering, `.animation(value:)` |
| `FolderPopupView.swift` | Same pattern for folder interior |
| `ContentView.swift` | Top-level overlay ZStack layer |
| `AppIconView.swift` | Opacity control for hiding original tile during drag |

## Testing Checklist

- [ ] Main grid: drag app across multiple cells, observe smooth displacement animation
- [ ] Folder interior: drag app between members, observe displacement
- [ ] `animateDrag` off: no animation but functionality intact
- [ ] Drag cancel: item rolls back to original position
- [ ] Cross-page drag: displacement works after page flip
- [ ] Drop onto folder: merge logic unaffected by displacement
- [ ] 2x2 enlarged folder: displacement skips occupied cells correctly
