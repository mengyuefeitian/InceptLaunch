## 1.6.19 - 2026-07-26

### Features
- Folder popup uses blurred wallpaper background (Liquid Glass aesthetic)
- Folder tiles scale up when a dragged app enters the acceptance threshold
- Live gap and create-folder sensing when dragging apps out of folders onto the grid
- Settings UI for grid layout, icon size (S/M/L), and show/hide app names
- Dynamic grid rows/columns driven by user preferences
- Russian localization and layout/icon preference keys

### Fixes
- Drag page-flip handoff to floating track, folder handoff ghost, and enlarged row overflow
- Restore folder popup internal reorder and drag-out
- Align search and enlarged folder frost with small-folder styling
- Search frost, editable field, grid spacing, and enlarged folder bounds

## 1.5.5 - 2026-07-25

### Features
- Restructure settings into sidebar navigation with About page
- Add eye badge for hidden apps in search results
- Support drag-to-reorder apps inside folder popups
- Animated live reorder in main grid with tile displacement and floating overlay
- Add implicit spring animation on grid tile position changes
- Add i18n (Japanese / Korean) with live language switch and logging improvements

### Fixes
- Menu bar icon sync, localize search/background labels, center placeholder
- Cache background images to prevent flicker during drag reorder
- Prevent double-move on drop and persist folder reorders
- Resolve variable shadowing in `computeGridTargetIndex` filter
- System app toggle and folder drag-out threshold

### Refactor
- Use ID-based `ForEach` identity for grid animation support
