# InceptLaunch

A native **Launchpad replacement for macOS 26 Tahoe** and newer.

macOS 26 removed the classic Launchpad in favor of a Spotlight-style Apps
launcher. InceptLaunch brings back the full-screen visual app grid — spatial
memory, manual layout, folders, and instant launch — built natively with
SwiftUI and AppKit.

<p align="center">
  <img src="Resources/InceptLaunch-icon-source.png" width="180" alt="InceptLaunch icon" />
</p>

## Features

- **Full-screen launch grid** — a borderless overlay showing your apps in a
  Launchpad-style grid with real system icons and page indicators.
- **Adaptive rows** — the grid scales its row count to your display
  (4 rows at 1080p, 6 at 1440p, 10 at 4K) so icons stay comfortably sized.
- **Search** — live filtering with pinyin support (full pinyin, initials, and
  substring matching), keyboard navigation, and one-tap-to-dismiss results.
- **Folders** — drag one app onto another to create a folder, rename it, open
  it in a popup grid, and drag apps back out.
- **Apple app folding** — on first launch, scattered `com.apple.*` apps are
  gathered into a single "Apple" folder; newly installed Apple apps are folded
  in automatically without disturbing apps you have placed yourself.
- **Directory folders** — multi-app directories (e.g. `/Applications/Python
  3.13`) collapse into a folder with a 2×2 icon preview.
- **Drag to reorder** — rearrange icons and move them across pages; layout is
  persisted and never shuffled by rescans.
- **Move to Trash** — long-press or right-click an icon to remove it (with a
  safety confirmation), powered by a reversible trash flow.
- **Global hotkey + menu bar** — open the overlay from anywhere with
  `⌥ Space` (Option + Space), or from the menu bar and Dock.
- **Layout persistence** — your pages, folders, and preferences are saved to
  `~/Library/Application Support/InceptLaunch/`.

## Requirements

- macOS 15.0+ (Sequoia or newer; designed for macOS 26 Tahoe)
- [Swiftly](https://www.swift.org/swiftly/) toolchain (Swift 6.3) — the
  Command Line Tools SwiftPM has a known linking bug on recent systems

## Build & run

```bash
# Build, assemble the .app bundle (with icon + ad-hoc signing), and launch it
./script/build_and_run.sh

# Build and verify the process launches
./script/build_and_run.sh --verify

# Stream logs while running
./script/build_and_run.sh --logs
```

## Run tests

```bash
swift test
```

Tests use the Swift Testing framework (`import Testing`). No Xcode required.

## Package as DMG

```bash
# Assemble the app first, then build a distributable DMG
./script/build_and_run.sh --verify
./script/package_dmg.sh
```

This produces `dist/InceptLaunch-<version>-local.dmg` with a drag-to-Applications
installer layout. The build is ad-hoc signed for local distribution (no
Developer ID or notarization).

## Project structure

```
Sources/InceptLaunch/
├── App/        # AppKit entry point, app delegate
├── Models/     # AppRecord, folders, layout, preferences
├── Services/   # Scanner, launcher, hotkey, menu bar, overlay window, trash
├── Stores/     # Layout store, view model, persistence
├── Support/    # Grid metrics, search matching, paths, JSON store
└── Views/      # SwiftUI grid, search, folders, settings
```

## How it works

InceptLaunch uses a traditional AppKit entry point (`main.swift` +
`AppDelegate`) rather than SwiftUI app scenes. The overlay is a borderless,
full-screen `NSWindow` raised above the menu bar that hosts the SwiftUI
`ContentView`. This avoids the scene-lifecycle behavior that would otherwise
keep the process hidden. App icons come from `NSWorkspace.icon(forFile:)`.

## Status

InceptLaunch is an active personal project covering the core Launchpad
experience: scanning, grid display, search, folders, drag-to-reorder, and
launch. See the [design spec](docs/superpowers/specs/) for the full product
roadmap.

## License

Personal project. All rights reserved.
