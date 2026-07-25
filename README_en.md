<div align="center">

<img src="Resources/InceptLaunch-icon-source.png" width="160" alt="InceptLaunch" />

# InceptLaunch

**The Launchpad macOS 26 took away — brought back, native and fast.**

A full-screen visual app grid with folders, instant search, and manual layout,
built with SwiftUI + AppKit for macOS Tahoe and newer.

[![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue?logo=apple)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.3-orange?logo=swift)](https://www.swift.org)
[![Release](https://img.shields.io/badge/release-1.5.5-brightgreen)](../../releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[简体中文](README.md) | **English**

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

## What's new in v1.5

- **Live drag-reorder in main grid** — tiles gracefully make way while you drag,
  a floating overlay follows your finger, and the layout is persisted on drop.
- **Implicit spring animation** — grid tile position changes animate with a
  spring, and honour the system "Reduce motion" setting.
- **Internationalization (i18n)** — Japanese and Korean join the existing
  languages, with live language switching and localized search and log output.
- **Settings restructure** — moved to a sidebar navigation with a new "About"
  page for a cleaner layout.
- **Hidden-app badge** — hidden apps show an eye icon in search results so they
  are easy to spot.

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
| **v0.4** Full replica | Edit mode, move-to-trash, multi-display, animation polish, keyboard nav | 🟡 Nearly done (multi-display remaining) |
| **v1.5** Experience upgrade | Live drag-reorder animation, i18n (ja/ko), settings restructure, hidden-app badge | ✅ Done |
| **v2.0** Stable release | Multi-display & Spaces, performance, first-run guide, auto-update, signing & notarization | 📋 Planned |

### Coming next

- **Multi-display & Spaces** — predictable overlay placement across monitors,
  full-screen apps, and Stage Manager, with focus restored on dismiss.
- **Edit mode** — long-press to enter a jiggle mode for batch organizing and
  hiding apps.
- **Multiple layouts** — switch between Work / Personal / Presentation grids.
- **Old Launchpad migration** — experimentally import pages and folders from
  the legacy Launchpad database.
- **Signing & notarization** — distribute via Developer ID so Gatekeeper
  warnings disappear entirely.

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

Released under the [MIT License](LICENSE). Copyright © 2026.
