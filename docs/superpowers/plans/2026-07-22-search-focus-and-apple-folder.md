# Search Auto-Focus & Apple Apps Auto-Folder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make keyboard input focus the search field the instant the overlay opens, and automatically collect Apple's own apps (`com.apple.*`) into a managed "Apple" folder.

**Architecture:** Focus is a small SwiftUI `@FocusState` wiring change in `ContentView`/`SearchFieldView`. The Apple folder is a new additive `LayoutStore.syncAppleFolder` method invoked from `LaunchpadViewModel.applyScanResult`, which routes `com.apple.*` records into a stable `folder:apple` and excludes them from top-level grid placement.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI + AppKit, SwiftPM executable, Swift Testing (`import Testing`, `@Test`, `#expect`). No XCTest/Xcode.

---

## Environment Notes (read first)

- The CommandLineTools SwiftPM is broken on this machine. Prepend the swiftly toolchain to `PATH` for every build/test command:
  ```bash
  export PATH="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin:$PATH"
  ```
- Run tests with `swift test`. Filter a single test with `swift test --filter <nameSubstring>`.
- Project root: `/Users/xiaoan/Documents/code/InceptLaunch`.
- Tests must NEVER use the default `LayoutPersistenceStore`/`PreferencesStore` (they write to the user's real Application Support files). Always inject a `JSONFileStore` pointed at a temp URL, as the existing tests do.

## File Structure

- Modify: `Sources/InceptLaunch/Views/SearchFieldView.swift` — accept a `@FocusState.Binding` and attach `.focused`.
- Modify: `Sources/InceptLaunch/Views/ContentView.swift` — own `@FocusState`, pass binding, request focus on appear.
- Modify: `Sources/InceptLaunch/Stores/LayoutStore.swift` — add `syncAppleFolder(appleAppIDs:name:now:)` and `appleFolderID`.
- Modify: `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift` — route Apple records in `applyScanResult`.
- Test: `Tests/InceptLaunchTests/LayoutStoreTests.swift` — 4 new tests.
- Test: `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift` — 1 new bootstrap test + helper.

---

## Task 1: Focus the search field when the overlay opens

This is pure SwiftUI focus wiring with no unit-testable surface; it is verified by building and by real-app visual check in Task 4.

**Files:**
- Modify: `Sources/InceptLaunch/Views/SearchFieldView.swift`
- Modify: `Sources/InceptLaunch/Views/ContentView.swift`

- [ ] **Step 1: Add a focus binding to SearchFieldView**

Replace the whole body of `SearchFieldView.swift` with:

```swift
import SwiftUI

struct SearchFieldView: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        TextField("Search", text: $text)
            .textFieldStyle(.plain)
            .focused($focused)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .frame(maxWidth: 420)
    }
}
```

- [ ] **Step 2: Own the focus state in ContentView**

In `ContentView.swift`, add a `@FocusState` property next to the other `@State`:

```swift
struct ContentView: View {
    @State private var viewModel = LaunchpadViewModel()
    @State private var openFolder: LaunchpadDisplayItem?
    @FocusState private var searchFocused: Bool
```

- [ ] **Step 3: Pass the binding to the search field**

In `ContentView.swift`, change the `SearchFieldView` construction:

```swift
                SearchFieldView(text: $viewModel.searchText, focused: $searchFocused)
                    .padding(.top, 60)
```

- [ ] **Step 4: Request focus when the overlay appears**

In `ContentView.swift`, add an `.onAppear` right after the existing `.task { viewModel.bootstrapScan() }` modifier on the `ZStack`:

```swift
        .task {
            viewModel.bootstrapScan()
        }
        .onAppear {
            // The window becomes key a beat after the hosting view appears;
            // defer the focus request briefly so it is not dropped.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
```

- [ ] **Step 5: Build to verify it compiles**

Run:
```bash
export PATH="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin:$PATH" && swift build
```
Expected: `Build complete!` with no errors.

- [ ] **Step 6: Commit**

```bash
git add Sources/InceptLaunch/Views/SearchFieldView.swift Sources/InceptLaunch/Views/ContentView.swift
git commit -m "feat: focus search field automatically when overlay opens"
```

---

## Task 2: LayoutStore.syncAppleFolder (TDD)

**Files:**
- Modify: `Sources/InceptLaunch/Stores/LayoutStore.swift`
- Test: `Tests/InceptLaunchTests/LayoutStoreTests.swift`

- [ ] **Step 1: Write the four failing tests**

Append to `Tests/InceptLaunchTests/LayoutStoreTests.swift`:

```swift
@Test func syncAppleFolderCreatesFolderForAppleApps() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail", "com.apple.Safari"])

    guard let folder = store.layout.folders.first(where: { $0.id == "folder:apple" }) else {
        Issue.record("expected folder:apple to be created")
        return
    }
    #expect(folder.name == "Apple")
    #expect(folder.items.sorted() == ["com.apple.Mail", "com.apple.Safari"])
    #expect(store.layout.pages.flatMap { $0 }.contains(.folder("folder:apple")))
}

@Test func syncAppleFolderAddsOnlyNewApps() {
    // Mail is on a page (user dragged it out -> settled), Safari is already a
    // member, Notes is brand new (nowhere yet).
    var store = LayoutStore(layout: .init(
        pages: [[.app("com.apple.Mail")]],
        folders: [LaunchpadFolder(
            id: "folder:apple", name: "Apple",
            items: ["com.apple.Safari"], createdAt: Date(), updatedAt: Date()
        )],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail", "com.apple.Safari", "com.apple.Notes"])

    let folder = store.layout.folders.first(where: { $0.id == "folder:apple" })!
    #expect(folder.items.contains("com.apple.Notes"))
    #expect(!folder.items.contains("com.apple.Mail"))
    // Mail stays on the page; it is not yanked back into the folder.
    #expect(store.layout.pages[0].contains(.app("com.apple.Mail")))
}

@Test func syncAppleFolderSkipsWhenFewerThanTwo() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Mail"])
    #expect(store.layout.folders.isEmpty)
}

@Test func syncAppleFolderKeepsWorkingAfterRename() {
    var store = LayoutStore(layout: .init(
        pages: [[.app("a")]],
        folders: [LaunchpadFolder(
            id: "folder:apple", name: "苹果",
            items: ["com.apple.Safari"], createdAt: Date(), updatedAt: Date()
        )],
        hiddenAppIDs: [],
        grid: .init(columns: 7, rows: 5, iconSize: 72)
    ))
    store.syncAppleFolder(appleAppIDs: ["com.apple.Safari", "com.apple.Notes"])

    let folder = store.layout.folders.first(where: { $0.id == "folder:apple" })!
    #expect(folder.name == "苹果")
    #expect(folder.items.contains("com.apple.Notes"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
export PATH="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin:$PATH" && swift test --filter syncAppleFolder
```
Expected: compile error — `value of type 'LayoutStore' has no member 'syncAppleFolder'`. (A compile failure is the Swift equivalent of a red test here.)

- [ ] **Step 3: Implement syncAppleFolder**

Add to `LayoutStore` (after `syncDirectoryFolders`, before `addAppToFolder`):

```swift
    /// Stable id of the managed folder that holds Apple's own apps.
    static let appleFolderID = "folder:apple"

    /// Keeps Apple's own apps (bundle id prefix `com.apple.`) together in one
    /// managed folder named "Apple".
    ///
    /// Membership is additive only: an app already placed somewhere — on a page
    /// or inside any folder — is considered settled and left alone, so apps a
    /// user drags out of the folder stay out. Only apps that appear nowhere yet
    /// (freshly installed) are collected. The folder is created the first time
    /// two or more unsettled Apple apps are seen; afterwards new apps simply
    /// join the existing folder (which may have been renamed — the id is stable).
    mutating func syncAppleFolder(appleAppIDs: [String], name: String = "Apple", now: Date = Date()) {
        let onPages = Set(layout.pages.flatMap { page in
            page.compactMap { item -> String? in
                if case .app(let id) = item { return id }
                return nil
            }
        })
        let inFolders = Set(layout.folders.flatMap(\.items))
        let unsettled = appleAppIDs.filter {
            !onPages.contains($0) && !inFolders.contains($0) && !layout.hiddenAppIDs.contains($0)
        }
        guard !unsettled.isEmpty else { return }

        if let index = layout.folders.firstIndex(where: { $0.id == Self.appleFolderID }) {
            layout.folders[index].items.append(contentsOf: unsettled)
            layout.folders[index].updatedAt = now
            return
        }

        // First sighting: only make a folder when there are at least two apps.
        guard unsettled.count >= 2 else { return }
        let folder = LaunchpadFolder(
            id: Self.appleFolderID,
            name: name,
            items: unsettled,
            createdAt: now,
            updatedAt: now
        )
        for appID in unsettled {
            removeItem(id: "app:\(appID)")
        }
        layout.folders.append(folder)
        if layout.pages.isEmpty { layout.pages = [[]] }
        layout.pages[0].insert(.folder(folder.id), at: 0)
        removeEmptyTrailingPages()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
export PATH="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin:$PATH" && swift test --filter syncAppleFolder
```
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Stores/LayoutStore.swift Tests/InceptLaunchTests/LayoutStoreTests.swift
git commit -m "feat: add LayoutStore.syncAppleFolder for managed Apple apps folder"
```

---

## Task 3: Route Apple apps in the view model (TDD)

**Files:**
- Modify: `Sources/InceptLaunch/Stores/LaunchpadViewModel.swift`
- Test: `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift`

- [ ] **Step 1: Write the failing bootstrap test + helper**

Append to `Tests/InceptLaunchTests/LaunchpadViewModelTests.swift` (before the `private final class RecordingTrasher` line):

```swift
@MainActor @Test func bootstrapRoutesAppleAppsToAppleFolder() throws {
    let scanDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-scan-\(UUID().uuidString)")
    try makeBundle(in: scanDir, name: "Mail", bundleID: "com.apple.Mail")
    try makeBundle(in: scanDir, name: "Safari", bundleID: "com.apple.Safari")
    try makeBundle(in: scanDir, name: "ThirdParty", bundleID: "com.example.ThirdParty")

    let layoutURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-layout-\(UUID().uuidString).json")
    let persistence = LayoutPersistenceStore(fileStore: JSONFileStore<LaunchpadLayout>(url: layoutURL))

    var preferences = UserPreferences.default
    preferences.scanDirectories = [scanDir.path]
    let preferencesURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-prefs-\(UUID().uuidString).json")
    let preferencesStore = PreferencesStore(fileStore: JSONFileStore<UserPreferences>(url: preferencesURL))
    try preferencesStore.save(preferences)

    let viewModel = LaunchpadViewModel(
        preferencesStore: preferencesStore,
        layoutPersistence: persistence,
        screenHeight: 1080
    )
    viewModel.bootstrapScan()

    let saved = try JSONDecoder.inceptLaunch.decode(
        LaunchpadLayout.self, from: Data(contentsOf: layoutURL)
    )
    let folder = saved.folders.first(where: { $0.id == "folder:apple" })
    #expect(folder != nil)
    #expect(Set(folder?.items ?? []) == ["bundle:com.apple.Mail", "bundle:com.apple.Safari"])

    // Apple apps must not appear as top-level grid items.
    let topLevelApps = saved.pages.flatMap { $0 }.compactMap { item -> String? in
        if case .app(let id) = item { return id }
        return nil
    }
    #expect(topLevelApps == ["bundle:com.example.ThirdParty"])

    try? FileManager.default.removeItem(at: layoutURL)
    try? FileManager.default.removeItem(at: preferencesURL)
    try? FileManager.default.removeItem(at: scanDir)
}

/// Writes a minimal `.app` bundle with the given bundle id into `root`.
private func makeBundle(in root: URL, name: String, bundleID: String) throws {
    let contents = root.appendingPathComponent("\(name).app/Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist = contents.appendingPathComponent("Info.plist")
    try """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>\(bundleID)</string>
      <key>CFBundleName</key>
      <string>\(name)</string>
    </dict>
    </plist>
    """.data(using: .utf8)!.write(to: plist)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
export PATH="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin:$PATH" && swift test --filter bootstrapRoutesAppleAppsToAppleFolder
```
Expected: FAIL — `folder` is nil (no `folder:apple` created yet) and Apple apps appear top-level.

- [ ] **Step 3: Route Apple records in applyScanResult**

In `LaunchpadViewModel.swift`, replace the body of `applyScanResult`:

```swift
    func applyScanResult(_ result: ScanResult) {
        appIndex.merge(scanResults: result.records)
        layoutStore.syncDirectoryFolders(result.directoryFolders)
        layoutStore.pruneApps(notIn: Set(result.records.map(\.id)))

        // Collect Apple's own apps into the managed "Apple" folder before adding
        // the rest to the grid, so freshly installed Apple apps land in the
        // folder rather than on a page.
        let appleIDs = result.records
            .filter { $0.bundleID?.hasPrefix("com.apple.") == true }
            .map(\.id)
        layoutStore.syncAppleFolder(appleAppIDs: appleIDs)

        let folderMemberIDs = Set(result.directoryFolders.flatMap(\.appIDs))
        let appleIDSet = Set(appleIDs)
        let topLevelIDs = result.records.map(\.id).filter {
            !folderMemberIDs.contains($0) && !appleIDSet.contains($0)
        }
        layoutStore.appendNewApps(topLevelIDs)
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
export PATH="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin:$PATH" && swift test --filter bootstrapRoutesAppleAppsToAppleFolder
```
Expected: PASS.

- [ ] **Step 5: Run the full suite to check for regressions**

Run:
```bash
export PATH="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin:$PATH" && swift test
```
Expected: all tests pass (previous 34 + 4 LayoutStore + 1 ViewModel = 39).

- [ ] **Step 6: Commit**

```bash
git add Sources/InceptLaunch/Stores/LaunchpadViewModel.swift Tests/InceptLaunchTests/LaunchpadViewModelTests.swift
git commit -m "feat: route com.apple.* apps into managed Apple folder on scan"
```

---

## Task 4: Real-app visual verification

**Files:** none (verification only)

- [ ] **Step 1: Build and refresh the dist bundle**

The computer_use tools attach to `dist/InceptLaunch.app`, so copy the fresh binary in first:

```bash
export PATH="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin:$PATH" && swift build && cp .build/debug/InceptLaunch dist/InceptLaunch.app/Contents/MacOS/InceptLaunch
```
Expected: `Build complete!`.

- [ ] **Step 2: Launch the app**

```bash
pkill -f "InceptLaunch.app/Contents/MacOS"; open dist/InceptLaunch.app
```

- [ ] **Step 3: Verify search auto-focus**

Open the overlay (hotkey or menu bar). Without clicking anything, type a few characters. Use computer_use `get_app_state` to confirm the search field contains the typed text and the grid filtered. (Note: the overlay auto-dismisses ~2.6s during computer_use sessions, so capture quickly after opening.)

- [ ] **Step 4: Verify the Apple folder**

Reopen the overlay and confirm an "Apple" folder tile is present on the grid. Open it and confirm system apps (Mail, Safari, etc.) are inside. Use the accessibility tree from `get_app_state`.

- [ ] **Step 5: Clean up and final commit (if any tweaks were needed)**

```bash
pkill -f "InceptLaunch.app/Contents/MacOS"
```
If verification required code tweaks, re-run `swift test`, then commit them. Otherwise no commit is needed for this task.
