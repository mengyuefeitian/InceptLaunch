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
