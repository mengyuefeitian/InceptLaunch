# InceptLaunch

InceptLaunch is a native macOS Launchpad replacement for macOS 26 Tahoe and newer.

## Run locally

```bash
./script/build_and_run.sh
```

## Verify process launch

```bash
./script/build_and_run.sh --verify
```

## Run tests

```bash
swift test
```

## Current scope

- Scans common application directories.
- Displays apps in a Launchpad-style grid.
- Supports search.
- Launches applications.
- Provides menu bar and shortcut entry points.
- Persists core preferences and layout model foundations.

## Known limitations in the current development build

- Option-Space global monitoring can require macOS permission approval.
- The SwiftPM development bundle is not signed or notarized.
- Drag-and-drop animations and deletion flow are reserved for the next polishing pass.
