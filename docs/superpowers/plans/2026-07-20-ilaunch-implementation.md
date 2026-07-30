# iLaunch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS Launchpad replacement that scans installed apps, presents a full-screen visual grid, supports search, launches apps, preserves user layout, and provides the foundation for folders, hiding, and settings.

**Architecture:** Use a SwiftPM macOS GUI app with SwiftUI for views and AppKit for desktop-only behavior such as foreground activation, global hotkeys, menu bar integration, app launching, and overlay windows. Keep business logic in testable models, stores, and services so scanning, searching, layout mutation, and launching can be verified without UI automation.

**Tech Stack:** Swift 6-compatible SwiftPM package, SwiftUI, AppKit, XCTest, local JSON persistence, project-local `script/build_and_run.sh`, Codex `.codex/environments/environment.toml`.

## Global Constraints

- Target platform is macOS 26 Tahoe and newer for product behavior, with source kept compatible with macOS 14+ APIs unless a task explicitly needs a newer API.
- iLaunch is a visual Launchpad replacement, not a Spotlight, Alfred, or Raycast clone.
- Manual layout must never be overwritten by scanning or automatic sorting.
- Hidden apps remain launchable from Finder/system locations but are excluded from the default iLaunch grid.
- Delete-style actions must be recoverable where possible; ordinary `.app` bundles move to Trash instead of permanent deletion.
- UI must support keyboard, mouse, and trackpad workflows.
- UI must adapt to Light/Dark mode and respect Reduce Motion.
- Every task must end with a test command or build verification and a git commit.

---

## File Structure

Create the project as a SwiftPM executable GUI app:

- `Package.swift`: package definition, app target, and test target.
- `Sources/iLaunch/App/iLaunchApp.swift`: `@main` app entry, app delegate bridge, scene setup.
- `Sources/iLaunch/App/AppDelegate.swift`: activation policy, foreground activation, and lifecycle wiring.
- `Sources/iLaunch/Views/ContentView.swift`: root composition for the launchpad overlay.
- `Sources/iLaunch/Views/LaunchpadGridView.swift`: paged app/folder grid UI.
- `Sources/iLaunch/Views/AppIconView.swift`: reusable app icon tile.
- `Sources/iLaunch/Views/SearchFieldView.swift`: search input wrapper.
- `Sources/iLaunch/Views/SettingsView.swift`: macOS settings scene content.
- `Sources/iLaunch/Models/AppRecord.swift`: app identity and metadata.
- `Sources/iLaunch/Models/LaunchpadItem.swift`: enum for app items and folders.
- `Sources/iLaunch/Models/LaunchpadFolder.swift`: folder model.
- `Sources/iLaunch/Models/LaunchpadLayout.swift`: pages, folders, hidden apps, grid settings.
- `Sources/iLaunch/Models/UserPreferences.swift`: persistent user preferences.
- `Sources/iLaunch/Stores/AppIndexStore.swift`: in-memory app index and scan merge rules.
- `Sources/iLaunch/Stores/LayoutStore.swift`: layout persistence and layout mutation.
- `Sources/iLaunch/Stores/PreferencesStore.swift`: preference persistence.
- `Sources/iLaunch/Services/AppScanner.swift`: scans `.app` bundles and extracts metadata.
- `Sources/iLaunch/Services/AppLauncher.swift`: launches or activates apps using `NSWorkspace`.
- `Sources/iLaunch/Services/IconCache.swift`: loads and caches app icons.
- `Sources/iLaunch/Services/GlobalHotKeyManager.swift`: registers the global toggle shortcut.
- `Sources/iLaunch/Services/MenuBarController.swift`: menu bar extra/status item actions.
- `Sources/iLaunch/Services/OverlayWindowController.swift`: full-screen overlay window presentation.
- `Sources/iLaunch/Support/Paths.swift`: application support paths and test overrides.
- `Sources/iLaunch/Support/JSONFileStore.swift`: reusable JSON read/write helper.
- `Sources/iLaunch/Support/SearchMatcher.swift`: deterministic app search ranking.
- `Tests/iLaunchTests/AppScannerTests.swift`
- `Tests/iLaunchTests/AppIndexStoreTests.swift`
- `Tests/iLaunchTests/LayoutStoreTests.swift`
- `Tests/iLaunchTests/SearchMatcherTests.swift`
- `Tests/iLaunchTests/AppLauncherTests.swift`
- `Tests/iLaunchTests/PreferencesStoreTests.swift`
- `script/build_and_run.sh`: single build/run/debug/log/verify entrypoint.
- `.codex/environments/environment.toml`: Codex Run button wiring.

---

### Task 1: Bootstrap SwiftPM macOS GUI App

**Files:**

- Create: `Package.swift`
- Create: `Sources/iLaunch/App/iLaunchApp.swift`
- Create: `Sources/iLaunch/App/AppDelegate.swift`
- Create: `Sources/iLaunch/Views/ContentView.swift`
- Create: `Tests/iLaunchTests/BootstrapTests.swift`
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

**Interfaces:**

- Produces: executable product `iLaunch`.
- Produces: app bundle identifier `com.ilaunch.iLaunch`.
- Produces: `ContentView` as the temporary root UI.
- Produces: `script/build_and_run.sh [run|--debug|--logs|--telemetry|--verify]`.

- [ ] **Step 1: Write the failing bootstrap test**

Create `Tests/iLaunchTests/BootstrapTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class BootstrapTests: XCTestCase {
    func testBundleIdentityConstants() {
        XCTAssertEqual(AppIdentity.name, "iLaunch")
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.ilaunch.iLaunch")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter BootstrapTests.testBundleIdentityConstants
```

Expected: build fails because `Package.swift`, target, and `AppIdentity` do not exist yet.

- [ ] **Step 3: Create the package and minimal app source**

Create `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iLaunch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "iLaunch", targets: ["iLaunch"])
    ],
    targets: [
        .executableTarget(
            name: "iLaunch",
            path: "Sources/iLaunch"
        ),
        .testTarget(
            name: "iLaunchTests",
            dependencies: ["iLaunch"],
            path: "Tests/iLaunchTests"
        )
    ]
)
```

Create `Sources/iLaunch/App/iLaunchApp.swift`:

```swift
import SwiftUI

enum AppIdentity {
    static let name = "iLaunch"
    static let bundleIdentifier = "com.ilaunch.iLaunch"
}

@main
struct iLaunchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(AppIdentity.name) {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            Text("iLaunch Settings")
                .frame(width: 420, height: 260)
        }
    }
}
```

Create `Sources/iLaunch/App/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

Create `Sources/iLaunch/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 48))
            Text("iLaunch")
                .font(.largeTitle)
            Text("Launchpad replacement prototype")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
```

- [ ] **Step 4: Create the build/run script**

Create `script/build_and_run.sh` and make it executable:

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="iLaunch"
BUNDLE_ID="com.ilaunch.iLaunch"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
```

Run:

```bash
chmod +x script/build_and_run.sh
```

- [ ] **Step 5: Add Codex Run button config**

Create `.codex/environments/environment.toml`:

```toml
# THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY
version = 1
name = "iLaunch"

[setup]
script = ""

[[actions]]
name = "Run"
icon = "run"
command = "./script/build_and_run.sh"
```

- [ ] **Step 6: Verify**

Run:

```bash
swift test --filter BootstrapTests.testBundleIdentityConstants
./script/build_and_run.sh --verify
```

Expected: test passes; build succeeds; `pgrep -x iLaunch` finds the app process.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources Tests script .codex
git commit -m "chore: bootstrap macOS app"
```

---

### Task 2: Domain Models and JSON Persistence

**Files:**

- Create: `Sources/iLaunch/Models/AppRecord.swift`
- Create: `Sources/iLaunch/Models/LaunchpadItem.swift`
- Create: `Sources/iLaunch/Models/LaunchpadFolder.swift`
- Create: `Sources/iLaunch/Models/LaunchpadLayout.swift`
- Create: `Sources/iLaunch/Models/UserPreferences.swift`
- Create: `Sources/iLaunch/Support/Paths.swift`
- Create: `Sources/iLaunch/Support/JSONFileStore.swift`
- Create: `Tests/iLaunchTests/LayoutStoreTests.swift`
- Create: `Tests/iLaunchTests/PreferencesStoreTests.swift`

**Interfaces:**

- Produces: `struct AppRecord: Codable, Equatable, Identifiable`.
- Produces: `enum LaunchpadItem: Codable, Equatable, Identifiable`.
- Produces: `struct LaunchpadLayout: Codable, Equatable`.
- Produces: `struct UserPreferences: Codable, Equatable`.
- Produces: `struct JSONFileStore<Value: Codable>`.
- Consumes: `AppIdentity.bundleIdentifier` from Task 1.

- [ ] **Step 1: Write failing model/persistence tests**

Create `Tests/iLaunchTests/LayoutStoreTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class LayoutStoreTests: XCTestCase {
    func testLayoutRoundTripsThroughJSON() throws {
        let app = AppRecord(
            id: "bundle:com.example.Editor",
            bundleID: "com.example.Editor",
            name: "Editor",
            localizedName: "Editor",
            path: "/Applications/Editor.app",
            iconCacheKey: "bundle:com.example.Editor",
            version: "1.0",
            source: .userApplications,
            isHidden: false,
            isMissing: false,
            lastSeenAt: Date(timeIntervalSince1970: 10),
            lastLaunchedAt: nil
        )
        let layout = LaunchpadLayout(
            pages: [[.app(app.id)]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        )
        let data = try JSONEncoder.iLaunch.encode(layout)
        let decoded = try JSONDecoder.iLaunch.decode(LaunchpadLayout.self, from: data)
        XCTAssertEqual(decoded, layout)
    }
}
```

Create `Tests/iLaunchTests/PreferencesStoreTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class PreferencesStoreTests: XCTestCase {
    func testDefaultPreferencesAreLaunchpadFocused() {
        let preferences = UserPreferences.default
        XCTAssertEqual(preferences.hotKey, "option+space")
        XCTAssertTrue(preferences.showMenuBarIcon)
        XCTAssertTrue(preferences.showDockIcon)
        XCTAssertEqual(preferences.overlayDisplayMode, .activeDisplay)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter LayoutStoreTests
swift test --filter PreferencesStoreTests
```

Expected: build fails because model types and JSON helpers do not exist.

- [ ] **Step 3: Add models**

Create model files with these public internal interfaces:

```swift
import Foundation

struct AppRecord: Codable, Equatable, Identifiable {
    enum Source: String, Codable, Equatable {
        case systemApplications
        case userApplications
        case localApplications
        case customDirectory
        case externalVolume
    }

    var id: String
    var bundleID: String?
    var name: String
    var localizedName: String?
    var path: String
    var iconCacheKey: String
    var version: String?
    var source: Source
    var isHidden: Bool
    var isMissing: Bool
    var lastSeenAt: Date
    var lastLaunchedAt: Date?
}
```

```swift
import Foundation

enum LaunchpadItem: Codable, Equatable, Identifiable {
    case app(String)
    case folder(String)

    var id: String {
        switch self {
        case .app(let id): return "app:\(id)"
        case .folder(let id): return "folder:\(id)"
        }
    }
}
```

```swift
import Foundation

struct LaunchpadFolder: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var items: [String]
    var createdAt: Date
    var updatedAt: Date
}
```

```swift
import Foundation

struct LaunchpadLayout: Codable, Equatable {
    struct Grid: Codable, Equatable {
        var columns: Int
        var rows: Int
        var iconSize: Double
    }

    var pages: [[LaunchpadItem]]
    var folders: [LaunchpadFolder]
    var hiddenAppIDs: Set<String>
    var grid: Grid

    static let empty = LaunchpadLayout(
        pages: [[]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    )
}
```

```swift
import Foundation

struct UserPreferences: Codable, Equatable {
    enum OverlayDisplayMode: String, Codable, Equatable {
        case activeDisplay
        case mouseDisplay
        case allDisplays
    }

    var hotKey: String
    var launchAtLogin: Bool
    var showMenuBarIcon: Bool
    var showDockIcon: Bool
    var backgroundBlur: Double
    var reduceMotion: Bool
    var showSystemApplications: Bool
    var overlayDisplayMode: OverlayDisplayMode
    var scanDirectories: [String]

    static let `default` = UserPreferences(
        hotKey: "option+space",
        launchAtLogin: false,
        showMenuBarIcon: true,
        showDockIcon: true,
        backgroundBlur: 0.72,
        reduceMotion: false,
        showSystemApplications: true,
        overlayDisplayMode: .activeDisplay,
        scanDirectories: [
            "/Applications",
            "~/Applications",
            "/System/Applications",
            "/System/Library/CoreServices/Applications"
        ]
    )
}
```

- [ ] **Step 4: Add JSON helpers and paths**

Create `Sources/iLaunch/Support/JSONFileStore.swift`:

```swift
import Foundation

extension JSONEncoder {
    static var iLaunch: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var iLaunch: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct JSONFileStore<Value: Codable> {
    let url: URL

    func load(default defaultValue: Value) throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return defaultValue
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.iLaunch.decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.iLaunch.encode(value)
        try data.write(to: url, options: [.atomic])
    }
}
```

Create `Sources/iLaunch/Support/Paths.swift`:

```swift
import Foundation

enum iLaunchPaths {
    static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(AppIdentity.name, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
```

- [ ] **Step 5: Verify**

Run:

```bash
swift test --filter LayoutStoreTests
swift test --filter PreferencesStoreTests
```

Expected: both tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/iLaunch/Models Sources/iLaunch/Support Tests/iLaunchTests
git commit -m "feat: add launchpad domain models"
```

---

### Task 3: App Scanner and Index Merge Rules

**Files:**

- Create: `Sources/iLaunch/Services/AppScanner.swift`
- Create: `Sources/iLaunch/Stores/AppIndexStore.swift`
- Create: `Tests/iLaunchTests/AppScannerTests.swift`
- Create: `Tests/iLaunchTests/AppIndexStoreTests.swift`

**Interfaces:**

- Produces: `struct AppScanner { func scan(directories: [URL], now: Date) -> [AppRecord] }`.
- Produces: `struct AppIndexStore { mutating func merge(scanResults: [AppRecord], now: Date) }`.
- Consumes: `AppRecord` from Task 2.

- [ ] **Step 1: Write failing scanner tests**

Create `Tests/iLaunchTests/AppScannerTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class AppScannerTests: XCTestCase {
    func testScannerReadsMinimalAppBundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appURL = root.appendingPathComponent("Example.app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = contents.appendingPathComponent("Info.plist")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>com.example.Example</string>
          <key>CFBundleName</key>
          <string>Example</string>
          <key>CFBundleShortVersionString</key>
          <string>2.5</string>
        </dict>
        </plist>
        """.data(using: .utf8)!.write(to: plist)

        let scanner = AppScanner()
        let records = scanner.scan(
            directories: [root],
            now: Date(timeIntervalSince1970: 20)
        )

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, "bundle:com.example.Example")
        XCTAssertEqual(records[0].name, "Example")
        XCTAssertEqual(records[0].version, "2.5")
        XCTAssertFalse(records[0].isMissing)
    }
}
```

Create `Tests/iLaunchTests/AppIndexStoreTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class AppIndexStoreTests: XCTestCase {
    func testMergeMarksMissingWithoutDeletingExistingRecord() {
        let now = Date(timeIntervalSince1970: 100)
        let old = AppRecord(
            id: "bundle:com.example.Editor",
            bundleID: "com.example.Editor",
            name: "Editor",
            localizedName: nil,
            path: "/Applications/Editor.app",
            iconCacheKey: "bundle:com.example.Editor",
            version: "1.0",
            source: .localApplications,
            isHidden: false,
            isMissing: false,
            lastSeenAt: now,
            lastLaunchedAt: nil
        )
        var store = AppIndexStore(records: [old.id: old])
        store.merge(scanResults: [], now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(store.records[old.id]?.isMissing, true)
        XCTAssertEqual(store.records[old.id]?.name, "Editor")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter AppScannerTests
swift test --filter AppIndexStoreTests
```

Expected: build fails because `AppScanner` and `AppIndexStore` do not exist.

- [ ] **Step 3: Add scanner and index store**

Create `Sources/iLaunch/Services/AppScanner.swift`:

```swift
import Foundation

struct AppScanner {
    func scan(directories: [URL], now: Date = Date()) -> [AppRecord] {
        directories.flatMap { scan(directory: $0, now: now) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scan(directory: URL, now: Date) -> [AppRecord] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> AppRecord? in
            guard let url = item as? URL, url.pathExtension == "app" else { return nil }
            return record(for: url, now: now)
        }
    }

    private func record(for appURL: URL, now: Date) -> AppRecord? {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data) as? [String: Any] else {
            return nil
        }

        let bundleID = plist["CFBundleIdentifier"] as? String
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let id = bundleID.map { "bundle:\($0)" } ?? "path:\(appURL.path)"
        let source = source(for: appURL)

        return AppRecord(
            id: id,
            bundleID: bundleID,
            name: name,
            localizedName: name,
            path: appURL.path,
            iconCacheKey: id,
            version: plist["CFBundleShortVersionString"] as? String,
            source: source,
            isHidden: false,
            isMissing: false,
            lastSeenAt: now,
            lastLaunchedAt: nil
        )
    }

    private func source(for appURL: URL) -> AppRecord.Source {
        if appURL.path.hasPrefix("/System/") { return .systemApplications }
        if appURL.path.hasPrefix(NSHomeDirectory()) { return .userApplications }
        if appURL.path.hasPrefix("/Applications") { return .localApplications }
        return .customDirectory
    }
}
```

Create `Sources/iLaunch/Stores/AppIndexStore.swift`:

```swift
import Foundation

struct AppIndexStore {
    private(set) var records: [String: AppRecord]

    init(records: [String: AppRecord] = [:]) {
        self.records = records
    }

    mutating func merge(scanResults: [AppRecord], now: Date = Date()) {
        let scannedIDs = Set(scanResults.map(\.id))

        for result in scanResults {
            var merged = result
            if let existing = records[result.id] {
                merged.isHidden = existing.isHidden
                merged.lastLaunchedAt = existing.lastLaunchedAt
            }
            records[result.id] = merged
        }

        for id in records.keys where !scannedIDs.contains(id) {
            records[id]?.isMissing = true
        }
    }

    func visibleRecords(hiddenIDs: Set<String>) -> [AppRecord] {
        records.values
            .filter { !$0.isHidden }
            .filter { !hiddenIDs.contains($0.id) }
            .filter { !$0.isMissing }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
```

- [ ] **Step 4: Verify**

Run:

```bash
swift test --filter AppScannerTests
swift test --filter AppIndexStoreTests
```

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/iLaunch/Services/AppScanner.swift Sources/iLaunch/Stores/AppIndexStore.swift Tests/iLaunchTests
git commit -m "feat: scan and merge application index"
```

---

### Task 4: Search Ranking and App Launching

**Files:**

- Create: `Sources/iLaunch/Support/SearchMatcher.swift`
- Create: `Sources/iLaunch/Services/AppLauncher.swift`
- Create: `Tests/iLaunchTests/SearchMatcherTests.swift`
- Create: `Tests/iLaunchTests/AppLauncherTests.swift`

**Interfaces:**

- Produces: `struct SearchMatcher { func ranked(query: String, records: [AppRecord]) -> [AppRecord] }`.
- Produces: `protocol WorkspaceLaunching`.
- Produces: `struct AppLauncher { func launch(_ record: AppRecord) -> LaunchResult }`.
- Consumes: `AppRecord` from Task 2.

- [ ] **Step 1: Write failing tests**

Create `Tests/iLaunchTests/SearchMatcherTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class SearchMatcherTests: XCTestCase {
    func testExactPrefixRanksBeforeSubstring() {
        let records = [
            record("Calendar"),
            record("Super Calendar"),
            record("Calculator")
        ]
        let results = SearchMatcher().ranked(query: "cal", records: records)
        XCTAssertEqual(results.map(\.name), ["Calculator", "Calendar", "Super Calendar"])
    }

    private func record(_ name: String) -> AppRecord {
        AppRecord(
            id: "bundle:com.example.\(name)",
            bundleID: "com.example.\(name)",
            name: name,
            localizedName: name,
            path: "/Applications/\(name).app",
            iconCacheKey: name,
            version: nil,
            source: .localApplications,
            isHidden: false,
            isMissing: false,
            lastSeenAt: Date(timeIntervalSince1970: 1),
            lastLaunchedAt: nil
        )
    }
}
```

Create `Tests/iLaunchTests/AppLauncherTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class AppLauncherTests: XCTestCase {
    func testMissingPathReturnsFailureWithoutOpeningWorkspace() {
        let workspace = MockWorkspace()
        let launcher = AppLauncher(workspace: workspace)
        let record = AppRecord(
            id: "bundle:missing",
            bundleID: "missing",
            name: "Missing",
            localizedName: nil,
            path: "/definitely/missing/Missing.app",
            iconCacheKey: "missing",
            version: nil,
            source: .customDirectory,
            isHidden: false,
            isMissing: false,
            lastSeenAt: Date(),
            lastLaunchedAt: nil
        )
        XCTAssertEqual(launcher.launch(record), .missingPath)
        XCTAssertEqual(workspace.openedURLs, [])
    }
}

private final class MockWorkspace: WorkspaceLaunching {
    var openedURLs: [URL] = []
    func openApplication(at url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter SearchMatcherTests
swift test --filter AppLauncherTests
```

Expected: build fails because matcher, launcher, and workspace protocol do not exist.

- [ ] **Step 3: Add search matcher**

Create `Sources/iLaunch/Support/SearchMatcher.swift`:

```swift
import Foundation

struct SearchMatcher {
    func ranked(query: String, records: [AppRecord]) -> [AppRecord] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return records.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return records.compactMap { record -> (AppRecord, Int)? in
            let name = record.name.lowercased()
            let bundleID = record.bundleID?.lowercased() ?? ""
            let score: Int

            if name == normalizedQuery {
                score = 0
            } else if name.hasPrefix(normalizedQuery) {
                score = 1
            } else if bundleID.hasPrefix(normalizedQuery) {
                score = 2
            } else if name.contains(normalizedQuery) {
                score = 3
            } else if bundleID.contains(normalizedQuery) {
                score = 4
            } else {
                return nil
            }

            return (record, score)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending
        }
        .map(\.0)
    }
}
```

- [ ] **Step 4: Add app launcher**

Create `Sources/iLaunch/Services/AppLauncher.swift`:

```swift
import AppKit
import Foundation

enum LaunchResult: Equatable {
    case launched
    case missingPath
    case failed
}

protocol WorkspaceLaunching {
    func openApplication(at url: URL) -> Bool
}

struct SystemWorkspaceLauncher: WorkspaceLaunching {
    func openApplication(at url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

struct AppLauncher {
    let workspace: WorkspaceLaunching

    init(workspace: WorkspaceLaunching = SystemWorkspaceLauncher()) {
        self.workspace = workspace
    }

    func launch(_ record: AppRecord) -> LaunchResult {
        guard FileManager.default.fileExists(atPath: record.path) else {
            return .missingPath
        }

        let opened = workspace.openApplication(at: URL(fileURLWithPath: record.path))
        return opened ? .launched : .failed
    }
}
```

- [ ] **Step 5: Verify**

Run:

```bash
swift test --filter SearchMatcherTests
swift test --filter AppLauncherTests
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/iLaunch/Support/SearchMatcher.swift Sources/iLaunch/Services/AppLauncher.swift Tests/iLaunchTests
git commit -m "feat: add search and app launching services"
```

---

### Task 5: Layout Mutation, Pages, and Folders

**Files:**

- Create: `Sources/iLaunch/Stores/LayoutStore.swift`
- Modify: `Tests/iLaunchTests/LayoutStoreTests.swift`

**Interfaces:**

- Produces: `struct LayoutStore`.
- Produces: `mutating func appendNewApps(_ appIDs: [String])`.
- Produces: `mutating func moveItem(id: String, toPage page: Int, index: Int)`.
- Produces: `mutating func createFolder(name: String, appIDs: [String], now: Date) -> LaunchpadFolder`.
- Produces: `mutating func hideApp(id: String)`.
- Consumes: `LaunchpadLayout`, `LaunchpadItem`, and `LaunchpadFolder` from Task 2.

- [ ] **Step 1: Add failing layout mutation tests**

Append to `Tests/iLaunchTests/LayoutStoreTests.swift`:

```swift
extension LayoutStoreTests {
    func testAppendNewAppsDoesNotDuplicateExistingItems() {
        var store = LayoutStore(layout: .init(
            pages: [[.app("a")]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 2, rows: 1, iconSize: 72)
        ))
        store.appendNewApps(["a", "b", "c"])
        XCTAssertEqual(store.layout.pages, [[.app("a"), .app("b")], [.app("c")]])
    }

    func testCreateFolderRemovesAppsFromPagesAndAddsFolder() {
        var store = LayoutStore(layout: .init(
            pages: [[.app("a"), .app("b"), .app("c")]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        ))
        let folder = store.createFolder(
            name: "Work",
            appIDs: ["a", "b"],
            now: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(folder.name, "Work")
        XCTAssertEqual(folder.items, ["a", "b"])
        XCTAssertEqual(store.layout.pages[0], [.folder(folder.id), .app("c")])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter LayoutStoreTests
```

Expected: build fails because `LayoutStore` does not exist.

- [ ] **Step 3: Add layout store**

Create `Sources/iLaunch/Stores/LayoutStore.swift`:

```swift
import Foundation

struct LayoutStore {
    private(set) var layout: LaunchpadLayout

    init(layout: LaunchpadLayout = .empty) {
        self.layout = layout
    }

    mutating func appendNewApps(_ appIDs: [String]) {
        let existing = Set(layout.pages.flatMap { page in
            page.compactMap { item -> String? in
                if case .app(let id) = item { return id }
                return nil
            }
        }).union(layout.folders.flatMap(\.items))

        let capacity = max(1, layout.grid.columns * layout.grid.rows)
        for appID in appIDs where !existing.contains(appID) && !layout.hiddenAppIDs.contains(appID) {
            if layout.pages.isEmpty { layout.pages = [[]] }
            if layout.pages[layout.pages.count - 1].count >= capacity {
                layout.pages.append([])
            }
            layout.pages[layout.pages.count - 1].append(.app(appID))
        }
    }

    mutating func moveItem(id: String, toPage page: Int, index: Int) {
        removeItem(id: id)
        while layout.pages.count <= page {
            layout.pages.append([])
        }
        let boundedIndex = min(max(0, index), layout.pages[page].count)
        layout.pages[page].insert(item(from: id), at: boundedIndex)
        removeEmptyTrailingPages()
    }

    mutating func createFolder(name: String, appIDs: [String], now: Date) -> LaunchpadFolder {
        let folder = LaunchpadFolder(
            id: "folder:\(UUID().uuidString)",
            name: name,
            items: appIDs,
            createdAt: now,
            updatedAt: now
        )
        let firstLocation = firstLocationOfApp(ids: appIDs) ?? (0, 0)
        for appID in appIDs {
            removeItem(id: "app:\(appID)")
        }
        layout.folders.append(folder)
        while layout.pages.count <= firstLocation.page {
            layout.pages.append([])
        }
        let index = min(firstLocation.index, layout.pages[firstLocation.page].count)
        layout.pages[firstLocation.page].insert(.folder(folder.id), at: index)
        removeEmptyTrailingPages()
        return folder
    }

    mutating func hideApp(id: String) {
        layout.hiddenAppIDs.insert(id)
        removeItem(id: "app:\(id)")
    }

    private func removeItem(id: String) {
        for pageIndex in layout.pages.indices {
            layout.pages[pageIndex].removeAll { $0.id == id }
        }
    }

    private func item(from id: String) -> LaunchpadItem {
        id.hasPrefix("folder:") ? .folder(id) : .app(id.replacingOccurrences(of: "app:", with: ""))
    }

    private func firstLocationOfApp(ids: [String]) -> (page: Int, index: Int)? {
        for pageIndex in layout.pages.indices {
            for itemIndex in layout.pages[pageIndex].indices {
                if case .app(let id) = layout.pages[pageIndex][itemIndex], ids.contains(id) {
                    return (pageIndex, itemIndex)
                }
            }
        }
        return nil
    }

    private mutating func removeEmptyTrailingPages() {
        while layout.pages.count > 1 && layout.pages.last?.isEmpty == true {
            layout.pages.removeLast()
        }
    }
}
```

- [ ] **Step 4: Verify**

Run:

```bash
swift test --filter LayoutStoreTests
swift test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/iLaunch/Stores/LayoutStore.swift Tests/iLaunchTests/LayoutStoreTests.swift
git commit -m "feat: add launchpad layout mutations"
```

---

### Task 6: View Model, Grid UI, Search UI, and Icons

**Files:**

- Create: `Sources/iLaunch/Services/IconCache.swift`
- Create: `Sources/iLaunch/Stores/LaunchpadViewModel.swift`
- Create: `Sources/iLaunch/Views/AppIconView.swift`
- Create: `Sources/iLaunch/Views/SearchFieldView.swift`
- Create: `Sources/iLaunch/Views/LaunchpadGridView.swift`
- Modify: `Sources/iLaunch/Views/ContentView.swift`
- Create: `Tests/iLaunchTests/LaunchpadViewModelTests.swift`

**Interfaces:**

- Produces: `@Observable final class LaunchpadViewModel`.
- Produces: `func refreshFromScanResults(_ records: [AppRecord])`.
- Produces: `var visiblePages: [[LaunchpadDisplayItem]]`.
- Produces: `func launchSelected() -> LaunchResult?`.
- Consumes: `AppIndexStore`, `LayoutStore`, `SearchMatcher`, and `AppLauncher`.

- [ ] **Step 1: Write failing view model test**

Create `Tests/iLaunchTests/LaunchpadViewModelTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class LaunchpadViewModelTests: XCTestCase {
    func testSearchFiltersVisibleItems() {
        let calendar = record("Calendar")
        let notes = record("Notes")
        let viewModel = LaunchpadViewModel(
            appIndex: AppIndexStore(records: [
                calendar.id: calendar,
                notes.id: notes
            ]),
            layoutStore: LayoutStore(layout: .init(
                pages: [[.app(calendar.id), .app(notes.id)]],
                folders: [],
                hiddenAppIDs: [],
                grid: .init(columns: 7, rows: 5, iconSize: 72)
            )),
            matcher: SearchMatcher(),
            launcher: AppLauncher(workspace: MockWorkspace())
        )

        viewModel.searchText = "cal"

        XCTAssertEqual(viewModel.visiblePages.flatMap { $0 }.map(\.title), ["Calendar"])
    }

    private func record(_ name: String) -> AppRecord {
        AppRecord(
            id: "bundle:com.example.\(name)",
            bundleID: "com.example.\(name)",
            name: name,
            localizedName: name,
            path: "/Applications/\(name).app",
            iconCacheKey: name,
            version: nil,
            source: .localApplications,
            isHidden: false,
            isMissing: false,
            lastSeenAt: Date(timeIntervalSince1970: 1),
            lastLaunchedAt: nil
        )
    }
}

private final class MockWorkspace: WorkspaceLaunching {
    func openApplication(at url: URL) -> Bool { true }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter LaunchpadViewModelTests
```

Expected: build fails because `LaunchpadViewModel` and display item types do not exist.

- [ ] **Step 3: Add view model and display item**

Create `Sources/iLaunch/Stores/LaunchpadViewModel.swift`:

```swift
import Foundation
import Observation

struct LaunchpadDisplayItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case app(AppRecord)
        case folder(LaunchpadFolder)
    }

    var id: String
    var title: String
    var kind: Kind
}

@Observable
final class LaunchpadViewModel {
    var searchText = ""
    var selectedItemID: String?

    private var appIndex: AppIndexStore
    private var layoutStore: LayoutStore
    private let matcher: SearchMatcher
    private let launcher: AppLauncher

    init(
        appIndex: AppIndexStore = AppIndexStore(),
        layoutStore: LayoutStore = LayoutStore(),
        matcher: SearchMatcher = SearchMatcher(),
        launcher: AppLauncher = AppLauncher()
    ) {
        self.appIndex = appIndex
        self.layoutStore = layoutStore
        self.matcher = matcher
        self.launcher = launcher
    }

    var visiblePages: [[LaunchpadDisplayItem]] {
        let recordsByID = appIndex.records

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [matcher.ranked(query: searchText, records: Array(recordsByID.values))
                .filter { !$0.isHidden && !$0.isMissing }
                .map { LaunchpadDisplayItem(id: $0.id, title: $0.name, kind: .app($0)) }]
        }

        return layoutStore.layout.pages.map { page in
            page.compactMap { item in
                switch item {
                case .app(let id):
                    guard let record = recordsByID[id], !record.isHidden, !record.isMissing else { return nil }
                    return LaunchpadDisplayItem(id: id, title: record.name, kind: .app(record))
                case .folder(let id):
                    guard let folder = layoutStore.layout.folders.first(where: { $0.id == id }) else { return nil }
                    return LaunchpadDisplayItem(id: id, title: folder.name, kind: .folder(folder))
                }
            }
        }
    }

    func refreshFromScanResults(_ records: [AppRecord]) {
        appIndex.merge(scanResults: records)
        layoutStore.appendNewApps(records.map(\.id))
    }

    func launchSelected() -> LaunchResult? {
        guard let selectedItemID,
              let item = visiblePages.flatMap({ $0 }).first(where: { $0.id == selectedItemID }),
              case .app(let record) = item.kind else {
            return nil
        }
        return launcher.launch(record)
    }
}
```

- [ ] **Step 4: Add icon service and SwiftUI views**

Create `Sources/iLaunch/Services/IconCache.swift`:

```swift
import AppKit
import Foundation

struct IconCache {
    func icon(for record: AppRecord) -> NSImage {
        NSWorkspace.shared.icon(forFile: record.path)
    }
}
```

Create `Sources/iLaunch/Views/AppIconView.swift`:

```swift
import SwiftUI

struct AppIconView: View {
    let item: LaunchpadDisplayItem

    var body: some View {
        VStack(spacing: 8) {
            icon
                .font(.system(size: 54))
                .frame(width: 72, height: 72)
            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 112, height: 112)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        switch item.kind {
        case .app:
            return Image(systemName: "app.fill")
                .foregroundStyle(.primary)
        case .folder:
            return Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
        }
    }
}
```

Create `Sources/iLaunch/Views/SearchFieldView.swift`:

```swift
import SwiftUI

struct SearchFieldView: View {
    @Binding var text: String

    var body: some View {
        TextField("Search", text: $text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .frame(maxWidth: 420)
    }
}
```

Create `Sources/iLaunch/Views/LaunchpadGridView.swift`:

```swift
import SwiftUI

struct LaunchpadGridView: View {
    let pages: [[LaunchpadDisplayItem]]
    let onLaunch: (LaunchpadDisplayItem) -> Void

    private let columns = Array(repeating: GridItem(.fixed(112), spacing: 18), count: 7)

    var body: some View {
        TabView {
            ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(page) { item in
                        AppIconView(item: item)
                            .onTapGesture {
                                onLaunch(item)
                            }
                    }
                }
                .padding(40)
            }
        }
        .tabViewStyle(.automatic)
    }
}
```

Modify `Sources/iLaunch/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel = LaunchpadViewModel()

    var body: some View {
        VStack(spacing: 28) {
            SearchFieldView(text: $viewModel.searchText)
            LaunchpadGridView(pages: viewModel.visiblePages) { item in
                if case .app(let record) = item.kind {
                    _ = AppLauncher().launch(record)
                }
            }
        }
        .padding(32)
        .frame(minWidth: 900, minHeight: 640)
        .background(.ultraThinMaterial)
    }
}
```

- [ ] **Step 5: Verify**

Run:

```bash
swift test --filter LaunchpadViewModelTests
swift test
./script/build_and_run.sh --verify
```

Expected: tests pass; app launches and shows search field plus empty grid.

- [ ] **Step 6: Commit**

```bash
git add Sources/iLaunch Tests/iLaunchTests/LaunchpadViewModelTests.swift
git commit -m "feat: add launchpad grid and search UI"
```

---

### Task 7: Real Startup Scanning and Persistent Layout

**Files:**

- Modify: `Sources/iLaunch/Stores/LaunchpadViewModel.swift`
- Create: `Sources/iLaunch/Stores/PreferencesStore.swift`
- Modify: `Sources/iLaunch/Views/ContentView.swift`
- Modify: `Tests/iLaunchTests/PreferencesStoreTests.swift`

**Interfaces:**

- Produces: `final class PreferencesStore`.
- Produces: `func load() throws -> UserPreferences`.
- Produces: `func save(_ preferences: UserPreferences) throws`.
- Produces: `func bootstrapScan()`.
- Consumes: `JSONFileStore`, `AppScanner`, `LayoutStore`, `AppIndexStore`.

- [ ] **Step 1: Add failing persistence test**

Append to `Tests/iLaunchTests/PreferencesStoreTests.swift`:

```swift
extension PreferencesStoreTests {
    func testPreferencesStoreRoundTripsToDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("preferences.json")
        let store = PreferencesStore(fileStore: JSONFileStore<UserPreferences>(url: url))
        var preferences = UserPreferences.default
        preferences.backgroundBlur = 0.5
        try store.save(preferences)
        XCTAssertEqual(try store.load().backgroundBlur, 0.5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter PreferencesStoreTests
```

Expected: build fails because `PreferencesStore` does not exist.

- [ ] **Step 3: Add preferences store**

Create `Sources/iLaunch/Stores/PreferencesStore.swift`:

```swift
import Foundation

final class PreferencesStore {
    private let fileStore: JSONFileStore<UserPreferences>

    init(fileStore: JSONFileStore<UserPreferences>? = nil) {
        if let fileStore {
            self.fileStore = fileStore
        } else {
            let directory = (try? iLaunchPaths.applicationSupportDirectory())
                ?? FileManager.default.temporaryDirectory
            self.fileStore = JSONFileStore<UserPreferences>(
                url: directory.appendingPathComponent("preferences.json")
            )
        }
    }

    func load() throws -> UserPreferences {
        try fileStore.load(default: .default)
    }

    func save(_ preferences: UserPreferences) throws {
        try fileStore.save(preferences)
    }
}
```

- [ ] **Step 4: Wire startup scan into view model**

Modify `LaunchpadViewModel` by adding:

```swift
private let scanner: AppScanner
private let preferencesStore: PreferencesStore

func bootstrapScan() {
    let preferences = (try? preferencesStore.load()) ?? .default
    let urls = preferences.scanDirectories.map { path in
        URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }
    let records = scanner.scan(directories: urls)
    refreshFromScanResults(records)
}
```

Update the initializer signature to accept `scanner: AppScanner = AppScanner()` and `preferencesStore: PreferencesStore = PreferencesStore()`, and assign both properties.

Modify `ContentView` to call:

```swift
.task {
    viewModel.bootstrapScan()
}
```

- [ ] **Step 5: Verify**

Run:

```bash
swift test --filter PreferencesStoreTests
swift test
./script/build_and_run.sh --verify
```

Expected: tests pass; app launches and populates the grid with discovered applications on a real Mac.

- [ ] **Step 6: Commit**

```bash
git add Sources/iLaunch Tests/iLaunchTests/PreferencesStoreTests.swift
git commit -m "feat: load preferences and scan apps on startup"
```

---

### Task 8: Overlay Window, Menu Bar Entry, and Hotkey Toggle

**Files:**

- Create: `Sources/iLaunch/Services/OverlayWindowController.swift`
- Create: `Sources/iLaunch/Services/MenuBarController.swift`
- Create: `Sources/iLaunch/Services/GlobalHotKeyManager.swift`
- Modify: `Sources/iLaunch/App/AppDelegate.swift`
- Modify: `Sources/iLaunch/App/iLaunchApp.swift`
- Create: `Tests/iLaunchTests/OverlayStateTests.swift`

**Interfaces:**

- Produces: `final class OverlayWindowController`.
- Produces: `func toggle()`.
- Produces: `final class MenuBarController`.
- Produces: `final class GlobalHotKeyManager`.
- Consumes: `ContentView`.

- [ ] **Step 1: Write failing state test for overlay visibility**

Create `Tests/iLaunchTests/OverlayStateTests.swift`:

```swift
import XCTest
@testable import iLaunch

final class OverlayStateTests: XCTestCase {
    func testOverlayStateToggle() {
        var state = OverlayState()
        XCTAssertFalse(state.isVisible)
        state.toggle()
        XCTAssertTrue(state.isVisible)
        state.toggle()
        XCTAssertFalse(state.isVisible)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter OverlayStateTests
```

Expected: build fails because `OverlayState` does not exist.

- [ ] **Step 3: Add overlay state and controller**

Create `Sources/iLaunch/Services/OverlayWindowController.swift`:

```swift
import AppKit
import SwiftUI

struct OverlayState {
    private(set) var isVisible = false

    mutating func toggle() {
        isVisible.toggle()
    }
}

final class OverlayWindowController {
    private var window: NSWindow?

    func toggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
            return
        }
        show()
    }

    func show() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: ContentView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
```

- [ ] **Step 4: Add menu bar and hotkey skeletons**

Create `Sources/iLaunch/Services/MenuBarController.swift`:

```swift
import AppKit

final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let overlay: OverlayWindowController

    init(overlay: OverlayWindowController) {
        self.overlay = overlay
        statusItem.button?.title = "Incept"
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open iLaunch", action: #selector(open), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func open() {
        overlay.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

Create `Sources/iLaunch/Services/GlobalHotKeyManager.swift`:

```swift
import AppKit

final class GlobalHotKeyManager {
    private let onToggle: () -> Void
    private var monitor: Any?

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [onToggle] event in
            if event.modifierFlags.contains(.option), event.keyCode == 49 {
                onToggle()
            }
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
```

Modify `AppDelegate` to retain controllers:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = OverlayWindowController()
    private var menuBarController: MenuBarController?
    private var hotKeyManager: GlobalHotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        menuBarController = MenuBarController(overlay: overlay)
        hotKeyManager = GlobalHotKeyManager { [overlay] in overlay.toggle() }
        hotKeyManager?.start()
    }
}
```

- [ ] **Step 5: Verify**

Run:

```bash
swift test --filter OverlayStateTests
swift test
./script/build_and_run.sh --verify
```

Manual verification:

- The menu bar shows `Incept`.
- Choosing `Open iLaunch` opens the overlay.
- Pressing Option-Space opens or closes the overlay when the app has accessibility/event-monitoring permission available.

- [ ] **Step 6: Commit**

```bash
git add Sources/iLaunch Tests/iLaunchTests/OverlayStateTests.swift
git commit -m "feat: add overlay menu bar and hotkey toggle"
```

---

### Task 9: Settings, Hidden Apps, and Safe Reset

**Files:**

- Modify: `Sources/iLaunch/Views/SettingsView.swift`
- Modify: `Sources/iLaunch/App/iLaunchApp.swift`
- Modify: `Sources/iLaunch/Stores/LaunchpadViewModel.swift`
- Modify: `Sources/iLaunch/Stores/LayoutStore.swift`
- Modify: `Tests/iLaunchTests/LayoutStoreTests.swift`

**Interfaces:**

- Produces: `SettingsView`.
- Produces: `mutating func unhideApp(id: String)`.
- Produces: `mutating func resetLayout(keepingHiddenApps: Bool)`.
- Consumes: `UserPreferences` and `LayoutStore`.

- [ ] **Step 1: Add failing hidden/reset tests**

Append to `LayoutStoreTests`:

```swift
extension LayoutStoreTests {
    func testHideAndUnhideApp() {
        var store = LayoutStore(layout: .init(
            pages: [[.app("a")]],
            folders: [],
            hiddenAppIDs: [],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        ))
        store.hideApp(id: "a")
        XCTAssertTrue(store.layout.hiddenAppIDs.contains("a"))
        XCTAssertEqual(store.layout.pages, [[]])
        store.unhideApp(id: "a")
        XCTAssertFalse(store.layout.hiddenAppIDs.contains("a"))
    }

    func testResetLayoutCanKeepHiddenApps() {
        var store = LayoutStore(layout: .init(
            pages: [[.app("a")]],
            folders: [],
            hiddenAppIDs: ["secret"],
            grid: .init(columns: 7, rows: 5, iconSize: 72)
        ))
        store.resetLayout(keepingHiddenApps: true)
        XCTAssertEqual(store.layout.pages, [[]])
        XCTAssertEqual(store.layout.hiddenAppIDs, ["secret"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter LayoutStoreTests
```

Expected: build fails because `unhideApp` and `resetLayout` do not exist.

- [ ] **Step 3: Add layout methods**

Add to `LayoutStore`:

```swift
mutating func unhideApp(id: String) {
    layout.hiddenAppIDs.remove(id)
}

mutating func resetLayout(keepingHiddenApps: Bool) {
    let hidden = keepingHiddenApps ? layout.hiddenAppIDs : []
    let grid = layout.grid
    layout = LaunchpadLayout(
        pages: [[]],
        folders: [],
        hiddenAppIDs: hidden,
        grid: grid
    )
}
```

- [ ] **Step 4: Add settings view**

Create or replace `Sources/iLaunch/Views/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @State private var preferences = UserPreferences.default

    var body: some View {
        Form {
            Section("Launch") {
                TextField("Global shortcut", text: $preferences.hotKey)
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $preferences.showMenuBarIcon)
                Toggle("Show Dock icon", isOn: $preferences.showDockIcon)
            }

            Section("Appearance") {
                Slider(value: $preferences.backgroundBlur, in: 0...1) {
                    Text("Background blur")
                }
                Toggle("Reduce motion", isOn: $preferences.reduceMotion)
            }

            Section("Apps") {
                Toggle("Show system applications", isOn: $preferences.showSystemApplications)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 420)
    }
}
```

Modify `iLaunchApp` Settings scene:

```swift
Settings {
    SettingsView()
}
```

- [ ] **Step 5: Verify**

Run:

```bash
swift test --filter LayoutStoreTests
swift test
./script/build_and_run.sh --verify
```

Manual verification:

- `iLaunch > Settings` opens a separate settings window.
- Settings fields render in Light and Dark mode.

- [ ] **Step 6: Commit**

```bash
git add Sources/iLaunch Tests/iLaunchTests/LayoutStoreTests.swift
git commit -m "feat: add settings and hidden app controls"
```

---

### Task 10: Final P0/P1 Verification Pass

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-07-20-ilaunch-launchpad-replica-design.md` only if verification reveals a product decision that needs clarification.

**Interfaces:**

- Consumes: all prior tasks.
- Produces: documented local run, test, and known limitation instructions.

- [ ] **Step 1: Create README**

Create `README.md`:

```markdown
# iLaunch

iLaunch is a native macOS Launchpad replacement for macOS 26 Tahoe and newer.

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
```

- [ ] **Step 2: Run full verification**

Run:

```bash
swift test
./script/build_and_run.sh --verify
```

Expected: tests pass; app process launches.

- [ ] **Step 3: Manual smoke test**

Verify:

- Open app with Dock icon.
- Open overlay from menu bar.
- Search for at least one installed app.
- Click the app tile.
- Reopen iLaunch.
- Open Settings.
- Quit from menu bar.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-07-20-ilaunch-launchpad-replica-design.md
git commit -m "docs: add local verification guide"
```

---

## Deferred Product Work After This Plan

These items are intentionally outside this first implementation plan because they need deeper AppKit/UI validation once the basic launcher works:

- Polished drag-and-drop reordering with cross-page hover timing.
- Folder open/close animation matching old Launchpad more closely.
- Safe uninstall and Trash integration.
- Multi-display overlay modes beyond the initial active display behavior.
- Import from legacy Launchpad database when available.
- Automatic helper/uninstaller cleanup rules.
- Multiple named layouts.

## Self-Review

- Spec coverage: P0 is covered by Tasks 1, 3, 4, 6, 7, and 8. P1 model foundations are covered by Tasks 5 and 9. Settings foundations are covered by Task 9. Full P1 animation, uninstall, and advanced multi-display behavior are listed as deferred polishing work because they depend on real UI behavior validation after the core launcher exists.
- Completion-marker scan: This plan uses concrete file paths, interfaces, commands, expected outcomes, and commit points. It does not contain undefined filler tasks.
- Type consistency: `AppRecord`, `LaunchpadItem`, `LaunchpadLayout`, `LayoutStore`, `AppIndexStore`, `SearchMatcher`, `AppLauncher`, and `LaunchpadViewModel` signatures are introduced before later tasks consume them.
