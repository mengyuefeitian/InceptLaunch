<div align="center">

<img src="Resources/InceptLaunch-icon-source.png" width="160" alt="InceptLaunch" />

# InceptLaunch

**The Launchpad macOS 26 took away — brought back, native and fast.**

A full-screen visual app grid with folders, instant search, and manual layout,
built with SwiftUI + AppKit for macOS Tahoe and newer.

[![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue?logo=apple)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.3-orange?logo=swift)](https://www.swift.org)
[![Release](https://img.shields.io/badge/release-1.0-brightgreen)](../../releases)
[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-lightgrey)](#license)

</div>

---

## Why

macOS 26 Tahoe replaced the classic Launchpad with a Spotlight-style Apps
launcher. It is efficient for searching, but it throws away what made
Launchpad lovable: **spatial memory**. Knowing *which page, which corner* your
app lives in is faster than typing every time.

InceptLaunch restores that experience — a calm, full-screen grid you can
arrange once and rely on forever.

## Highlights

- **Full-screen grid** — a borderless overlay with real system icons, page
  indicators, and rows that adapt to your display.
- **Instant search** — live filtering with full **pinyin** support (type `yy`
  to find 音乐 / Music), keyboard navigation, and tap-anywhere to dismiss.
- **Folders** — drag one app onto another to group it; rename, open in a
  popup grid, drag apps back out.
- **Smart Apple folding** — dozens of `com.apple.*` apps tidy themselves into
  one "Apple" folder on first launch, then quietly fold in new ones without
  disturbing your layout.
- **Drag to arrange** — reorder icons and move them across pages; your layout
  is saved and never reshuffled by rescans.
- **Move to Trash** — long-press or right-click to remove an app, with a
  safety confirmation.
- **Always one keystroke away** — open from anywhere with `⌥ Space`, the menu
  bar, or the Dock.

## Install

Download the latest `InceptLaunch-*.dmg` from
[Releases](../../releases), open it, and drag **InceptLaunch** into
**Applications**.

> The current build is ad-hoc signed for personal distribution. On first
> launch you may need to right-click → **Open** to bypass Gatekeeper.

## Quick start

1. Launch InceptLaunch.
2. Press `⌥ Space` (Option + Space) to open the grid.
3. Click an app to launch it, or start typing to search.
4. Drag apps to rearrange; drop one onto another to make a folder.
5. Press `Esc` or click empty space to dismiss.

## Roadmap

Where InceptLaunch is headed, tracked against the original
[design spec](docs/superpowers/specs/2026-07-20-inceptlaunch-launchpad-replica-design.md).

| Stage | Focus | Status |
|-------|-------|--------|
| **v0.1** Prototype | App scanning, grid, search, launch, menu bar | ✅ Done |
| **v0.2** Core experience | Full-screen overlay, global hotkey, paging, settings, layout persistence | ✅ Done |
| **v0.3** Manual organization | Drag to reorder, cross-page move, folders, Apple & directory folding | ✅ Done |
| **v0.4** Full replica | Edit mode, move-to-trash, multi-display, animation polish, keyboard nav | 🚧 In progress |
| **v1.0** Stable release | Performance, error handling, first-run guide, auto-update, signing & notarization | 📋 Planned |

### Coming next

- **Edit mode** — long-press to enter a jiggle mode for batch organizing and
  hiding apps.
- **Hide, don't delete** — hide low-value apps (helpers, uninstallers) and
  restore them from settings.
- **Multi-display & Spaces** — predictable overlay placement across monitors,
  full-screen apps, and Stage Manager, with focus restored on dismiss.
- **Animation polish** — open/close, paging, and folder transitions that
  respect the system "Reduce motion" setting.
- **Multiple layouts** — switch between Work / Personal / Presentation grids.
- **Old Launchpad migration** — experimentally import pages and folders from
  the legacy Launchpad database.

## Design principles

InceptLaunch follows a "Launchpad first" philosophy:

- Manual layout over smart sorting.
- Visual grid over command input.
- Hide over delete.
- Reliable launch over fancy animation.
- Local persistence over cloud sync.

The goal is a trustworthy system companion, not a feature-bloated launcher
with a shaky core.

## Contributing

This is currently a personal project. Ideas and bug reports are welcome via
[Issues](../../issues).

## License

Copyright © 2026. All rights reserved.
