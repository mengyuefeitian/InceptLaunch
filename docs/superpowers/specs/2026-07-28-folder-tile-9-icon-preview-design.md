# Closed-folder tile: 3x3 (9-icon) preview

## Objective

The small, closed-state folder tile on the main Launchpad grid (`FolderTileView`
in `Sources/iLaunch/Views/AppIconView.swift`) currently previews only 4
member app icons in a 2x2 grid. Native macOS Launchpad/Finder folder icons show
a 3x3 grid of up to 9 member icons. Match that.

The already-expanded/open folder view (`EnlargedFolderTileView`) already shows
9 icons per page and needs no change.

## Change

In `FolderTileView` (`AppIconView.swift:137-175`):

- `preview`: `Array(members.prefix(4))` -> `Array(members.prefix(9))`
- Sizing constants:
  - `cellSize`: `size * 0.36` -> `size * 0.24`
  - `gridSpacing`: `size * 0.06` -> `size * 0.035`
  - These preserve roughly the same outer margin proportion the 2x2 grid had
    (~0.105 * size per side), so the 3x3 cluster sits inside the tile the same
    way the 2x2 one did — icons just get smaller to fit more of them.
- `Grid` body: 2 `GridRow`s of 2 cells -> 3 `GridRow`s of 3 cells (`cell(0)`
  through `cell(8)`).
- `cell(_:)` helper is unchanged (bounds-checks `index < preview.count`, shows
  `Color.clear` filler otherwise) — just called for 9 indices instead of 4.

## Testing

- Existing tests don't cover `FolderTileView` pixel layout; this is a pure
  SwiftUI view change with no behavioral/data-model impact. Verify by
  building and visually inspecting a folder with >=9 apps and a folder with
  <9 apps (partial grid with empty cells) in the running app.

## Out of scope

- `EnlargedFolderTileView` (open folder popup) — already 3x3/9 per page.
- Any drag-and-drop, folder creation, or folder membership logic.
