# Configurable Global Hotkey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user record a custom global hotkey (replacing the hardcoded Option+Space) in Settings, with live conflict detection against other apps' Carbon-registered hotkeys.

**Architecture:** `UserPreferences.hotKey: String` (dead, never parsed) is replaced with `hotKeyCode`/`hotKeyModifiers: UInt32`. `GlobalHotKeyManager` gains `updateHotKey(keyCode:modifiers:) -> Bool`, which attempts a live re-registration and rolls back to the previous hotkey on failure — the Carbon `OSStatus` from that attempt *is* the conflict signal, no static blocklist needed. A new pure-logic `HotKeyCapture` enum validates candidate combos (must have a modifier, must not be bare Esc) and renders a display string. A new `HotKeyRecorderRow` view captures the next keydown via a local `NSEvent` monitor and drives the manager + preferences.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Carbon (`RegisterEventHotKey`, `UCKeyTranslate`), Swift Testing (`@Test`/`#expect`).

## Global Constraints

- macOS 15 minimum (per `Package.swift`) — no availability guards needed for any API used here.
- Follow the existing `UserPreferences` decode pattern: new/changed fields use `(try? c.decodeIfPresent(...)) ?? default` so old `preferences.json` files on disk keep loading.
- Every new user-facing string needs an entry in all 5 language dictionaries in `Sources/InceptLaunch/Support/Localizer.swift` (en, zh, ja, ko, ru) — the existing pattern has no fallback for a missing key in a non-English language, so a skipped language shows a blank/garbled label.
- Default behavior for existing users must stay Option+Space after upgrade.

---

### Task 1: Replace `hotKey: String` with `hotKeyCode`/`hotKeyModifiers` in `UserPreferences`

**Files:**
- Modify: `Sources/InceptLaunch/Models/UserPreferences.swift`
- Test: `Tests/InceptLaunchTests/PreferencesStoreTests.swift`

**Interfaces:**
- Produces: `UserPreferences.hotKeyCode: UInt32` (default `49`, i.e. `kVK_Space`), `UserPreferences.hotKeyModifiers: UInt32` (default `2048`, i.e. Carbon `optionKey`).

- [ ] **Step 1: Write the failing test**

Add to `Tests/InceptLaunchTests/PreferencesStoreTests.swift`:

```swift
@Test func decodingLegacyPreferencesWithoutHotKeyFieldsUsesOptionSpaceDefault() throws {
    // Simulates a preferences.json written before this feature existed —
    // it has no hotKeyCode/hotKeyModifiers keys at all.
    let legacyJSON = """
    {
        "hotKey": "option+space",
        "launchAtLogin": false,
        "showMenuBarIcon": true,
        "showDockIcon": true,
        "backgroundBlur": 0.72,
        "reduceMotion": false,
        "showSystemApplications": true,
        "overlayDisplayMode": "activeDisplay",
        "scanDirectories": ["/Applications"]
    }
    """
    let decoded = try JSONDecoder.inceptLaunch.decode(UserPreferences.self, from: Data(legacyJSON.utf8))
    #expect(decoded.hotKeyCode == 49)
    #expect(decoded.hotKeyModifiers == 2048)
}

@Test func hotKeyFieldsRoundTripThroughJSON() throws {
    var preferences = UserPreferences.default
    preferences.hotKeyCode = 40 // kVK_ANSI_K
    preferences.hotKeyModifiers = 256 | 512 // cmdKey | shiftKey
    let data = try JSONEncoder.inceptLaunch.encode(preferences)
    let decoded = try JSONDecoder.inceptLaunch.decode(UserPreferences.self, from: data)
    #expect(decoded.hotKeyCode == 40)
    #expect(decoded.hotKeyModifiers == 768)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PreferencesStoreTests`
Expected: FAIL to compile — `hotKeyCode`/`hotKeyModifiers` don't exist on `UserPreferences` yet.

- [ ] **Step 3: Update `UserPreferences`**

In `Sources/InceptLaunch/Models/UserPreferences.swift`:

Replace:
```swift
    var hotKey: String
    var launchAtLogin: Bool
```
with:
```swift
    var hotKeyCode: UInt32
    var hotKeyModifiers: UInt32
    var launchAtLogin: Bool
```

Replace the `default` static instance's `hotKey: "option+space",` line with:
```swift
        hotKeyCode: 49,        // kVK_Space
        hotKeyModifiers: 2048, // Carbon optionKey
```

Replace the `CodingKeys` line:
```swift
        case hotKey, launchAtLogin, showMenuBarIcon, showDockIcon
```
with:
```swift
        case hotKeyCode, hotKeyModifiers, launchAtLogin, showMenuBarIcon, showDockIcon
```

Replace the memberwise `init` parameter `hotKey: String,` with `hotKeyCode: UInt32, hotKeyModifiers: UInt32,` and the body line `self.hotKey = hotKey` with:
```swift
        self.hotKeyCode = hotKeyCode
        self.hotKeyModifiers = hotKeyModifiers
```

Replace the `init(from:)` line:
```swift
        hotKey = try c.decode(String.self, forKey: .hotKey)
```
with:
```swift
        hotKeyCode = (try? c.decodeIfPresent(UInt32.self, forKey: .hotKeyCode)) ?? 49
        hotKeyModifiers = (try? c.decodeIfPresent(UInt32.self, forKey: .hotKeyModifiers)) ?? 2048
```

- [ ] **Step 3b: Interim fix so the rest of the project still builds**

`Sources/InceptLaunch/Views/SettingsView.swift` (`GeneralSettingsView`) still references
the now-removed `preferences.hotKey` in two places. Task 5 replaces this UI with the real
hotkey recorder, but until then the project must still build. Apply this interim,
non-interactive placeholder now.

In `Sources/InceptLaunch/Views/SettingsView.swift`, replace:
```swift
                TextField(Localizer.t("settings.hotKey"), text: $preferences.hotKey)
```
with:
```swift
                Text(Localizer.t("settings.hotKey"))
```

Then replace:
```swift
        .onChange(of: preferences.hotKey) { _, _ in onSave() }
        .onChange(of: preferences.launchAtLogin) { _, newValue in
```
with:
```swift
        .onChange(of: preferences.launchAtLogin) { _, newValue in
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift build && swift test --filter PreferencesStoreTests`
Expected: PASS. Then run `swift test` (full suite).
Expected: PASS — Step 3b above is what keeps `SettingsView.swift` compiling now that
`hotKey` is gone; if `swift build` still fails, you missed a reference to
`preferences.hotKey` somewhere (grep for it — there must be none left after Step 3b).

- [ ] **Step 5: Commit**

Include the `SettingsView.swift` interim fix in this commit — it is scaffolding this task
introduced to keep the build green, not scope creep.

```bash
git add Sources/InceptLaunch/Models/UserPreferences.swift Sources/InceptLaunch/Views/SettingsView.swift Tests/InceptLaunchTests/PreferencesStoreTests.swift
git commit -m "feat: replace dead hotKey string preference with keycode/modifiers"
```

---

### Task 2: `HotKeyCapture` — pure validation, modifier translation, and display string

**Files:**
- Create: `Sources/InceptLaunch/Services/HotKeyCapture.swift`
- Test: Create `Tests/InceptLaunchTests/HotKeyCaptureTests.swift`

**Interfaces:**
- Consumes: nothing (pure, standalone).
- Produces: `HotKeyCapture.isValid(keyCode: UInt32, modifiers: UInt32) -> Bool`, `HotKeyCapture.carbonModifiers(from: NSEvent.ModifierFlags) -> UInt32`, `HotKeyCapture.displayString(keyCode: UInt32, modifiers: UInt32) -> String`. Task 3 and Task 5 both call these.

- [ ] **Step 1: Write the failing test**

Create `Tests/InceptLaunchTests/HotKeyCaptureTests.swift`:

```swift
import AppKit
import Carbon
import Testing
@testable import InceptLaunch

@Test func rejectsComboWithNoModifier() {
    #expect(HotKeyCapture.isValid(keyCode: UInt32(kVK_ANSI_K), modifiers: 0) == false)
}

@Test func rejectsBareEscapeEvenWithModifier() {
    #expect(HotKeyCapture.isValid(keyCode: UInt32(kVK_Escape), modifiers: UInt32(optionKey)) == false)
}

@Test func acceptsOptionSpace() {
    #expect(HotKeyCapture.isValid(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) == true)
}

@Test func acceptsCommandShiftK() {
    let modifiers = UInt32(cmdKey) | UInt32(shiftKey)
    #expect(HotKeyCapture.isValid(keyCode: UInt32(kVK_ANSI_K), modifiers: modifiers) == true)
}

@Test func translatesCommandAndOptionModifierFlags() {
    let flags: NSEvent.ModifierFlags = [.command, .option]
    #expect(HotKeyCapture.carbonModifiers(from: flags) == UInt32(cmdKey) | UInt32(optionKey))
}

@Test func translatesNoModifierFlagsToZero() {
    #expect(HotKeyCapture.carbonModifiers(from: []) == 0)
}

@Test func displaysOptionSpace() {
    #expect(HotKeyCapture.displayString(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) == "⌥Space")
}

@Test func displaysCommandShiftReturn() {
    let modifiers = UInt32(cmdKey) | UInt32(shiftKey)
    #expect(HotKeyCapture.displayString(keyCode: UInt32(kVK_Return), modifiers: modifiers) == "⌘⇧Return")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HotKeyCaptureTests`
Expected: FAIL to compile — `HotKeyCapture` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `Sources/InceptLaunch/Services/HotKeyCapture.swift`:

```swift
import AppKit
import Carbon

/// Pure logic for recording a global hotkey: validating a captured
/// keycode/modifier combo, translating AppKit modifier flags to the Carbon
/// constants `GlobalHotKeyManager` needs, and rendering a display string.
/// Kept separate from `GlobalHotKeyManager` (which owns the live, stateful
/// Carbon registration) so this part is unit-testable without touching any
/// system API.
enum HotKeyCapture {
    /// A combo is valid to register when it holds at least one modifier
    /// (so we never hijack plain typing) and isn't bare Esc (reserved to
    /// close the overlay).
    static func isValid(keyCode: UInt32, modifiers: UInt32) -> Bool {
        guard modifiers != 0 else { return false }
        guard keyCode != UInt32(kVK_Escape) else { return false }
        return true
    }

    /// Translates AppKit's modifier flags (captured from the recording
    /// NSEvent monitor) into the Carbon modifier mask `RegisterEventHotKey`
    /// expects.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// Human-readable label, e.g. "⌥Space", "⌘⇧K".
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += keyLabel(for: keyCode)
        return result
    }

    /// Special-cased non-printable keys first (deterministic, no keyboard
    /// layout lookup needed); anything else falls back to the current
    /// keyboard layout via Carbon's UCKeyTranslate so labels are correct
    /// even on non-US layouts.
    private static func keyLabel(for keyCode: UInt32) -> String {
        let special: [Int: String] = [
            kVK_Space: "Space",
            kVK_Return: "Return",
            kVK_Tab: "Tab",
            kVK_Delete: "Delete",
            kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←",
            kVK_RightArrow: "→",
            kVK_UpArrow: "↑",
            kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
        ]
        if let label = special[Int(keyCode)] { return label }
        return layoutLabel(for: keyCode) ?? "Key\(keyCode)"
    }

    private static func layoutLabel(for keyCode: UInt32) -> String? {
        guard let sourceUnmanaged = TISCopyCurrentKeyboardLayoutInputSource() else { return nil }
        let source = sourceUnmanaged.takeRetainedValue()
        guard let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPointer).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { rawPointer -> String? in
            guard let keyLayoutPointer = rawPointer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return nil
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(
                keyLayoutPointer,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift build && swift test --filter HotKeyCaptureTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Services/HotKeyCapture.swift Tests/InceptLaunchTests/HotKeyCaptureTests.swift
git commit -m "feat: add HotKeyCapture validation and display-string logic"
```

---

### Task 3: `GlobalHotKeyManager.updateHotKey` with rollback on conflict

**Files:**
- Modify: `Sources/InceptLaunch/Services/GlobalHotKeyManager.swift`
- Modify: `Sources/InceptLaunch/App/AppDelegate.swift`

**Interfaces:**
- Consumes: `HotKeyCapture` is not required here (manager stays keycode/modifier-agnostic).
- Produces: `GlobalHotKeyManager.start(keyCode: UInt32, modifiers: UInt32)` (replaces the old no-arg `start()`), `GlobalHotKeyManager.updateHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool`. Task 5's `HotKeyRecorderRow` calls `updateHotKey`.

There is no automated test for this task (see spec's Testing section — a live Carbon registration against a process-wide event target can't be simulated for "another app already holds this combo" in an automated test). Verify manually per Step 4.

- [ ] **Step 1: Modify `GlobalHotKeyManager`**

In `Sources/InceptLaunch/Services/GlobalHotKeyManager.swift`, replace the `start()` method and the two stored properties `hotKeyRef`/`eventHandlerRef` handling with:

```swift
final class GlobalHotKeyManager: @unchecked Sendable {
    private let onToggle: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var currentKeyCode: UInt32 = UInt32(kVK_Space)
    private var currentModifiers: UInt32 = UInt32(optionKey)
    private var nextHotKeyID: UInt32 = 1

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    /// Installs the Carbon event handler (once) and registers the initial
    /// hotkey. Call once at launch with the user's stored preference.
    func start(keyCode: UInt32, modifiers: UInt32) {
        installEventHandlerIfNeeded()
        currentKeyCode = keyCode
        currentModifiers = modifiers
        register(keyCode: keyCode, modifiers: modifiers)
    }

    /// Unregisters the current hotkey and registers `keyCode`/`modifiers`.
    /// Returns `false` (and leaves the previous hotkey active) if the new
    /// combo is already registered by another app — the Carbon
    /// `RegisterEventHotKey` error is the only conflict signal available;
    /// there's no API to enumerate who holds a combo.
    @discardableResult
    func updateHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let previousKeyCode = currentKeyCode
        let previousModifiers = currentModifiers
        unregisterCurrent()
        if register(keyCode: keyCode, modifiers: modifiers) {
            currentKeyCode = keyCode
            currentModifiers = modifiers
            return true
        }
        // Roll back so the overlay toggle keeps working.
        _ = register(keyCode: previousKeyCode, modifiers: previousModifiers)
        return false
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                // Hop to main; overlay activation must not race Carbon's own
                // event unwind (that was stealing key focus back).
                DispatchQueue.main.async {
                    manager.onToggle()
                }
                return noErr
            },
            1, &eventType, selfPtr, &eventHandlerRef
        )
    }

    /// Registers `keyCode`/`modifiers` under a fresh hotkey ID. Returns
    /// whether registration succeeded.
    @discardableResult
    private func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        nextHotKeyID += 1
        let hotKeyID = EventHotKeyID(signature: 0x494E4350, id: nextHotKeyID) // "INCP"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    private func unregisterCurrent() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    func stop() {
        unregisterCurrent()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    /// Returns true if the app has accessibility permission.
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility permission. Opens System Settings.
    @MainActor
    static func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandlerRef { RemoveEventHandler(handler) }
    }
}
```

(This keeps the existing doc comment at the top of the file as-is — only the body changes.)

- [ ] **Step 2: Update the call site in `AppDelegate`**

In `Sources/InceptLaunch/App/AppDelegate.swift`, replace:
```swift
        hotKeyManager?.start()
```
with:
```swift
        hotKeyManager?.start(keyCode: prefs.hotKeyCode, modifiers: prefs.hotKeyModifiers)
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 4: Manual verification (documented, not automated)**

1. Run the app, confirm Option+Space still opens/closes the overlay (unchanged default).
2. In a Swift REPL or scratch test, construct two `GlobalHotKeyManager` instances, `start()` the first with a given combo, then call `updateHotKey` on the second with the *same* combo — confirm it returns `false` and the first manager's hotkey still fires. Remove the scratch code after confirming; this is exploratory, not a committed test (see Task heading for why).

- [ ] **Step 5: Commit**

```bash
git add Sources/InceptLaunch/Services/GlobalHotKeyManager.swift Sources/InceptLaunch/App/AppDelegate.swift
git commit -m "feat: support live hotkey re-registration with conflict rollback"
```

---

### Task 4: Thread `GlobalHotKeyManager` down to Settings

**Files:**
- Modify: `Sources/InceptLaunch/App/AppDelegate.swift`
- Modify: `Sources/InceptLaunch/Services/MenuBarController.swift`
- Modify: `Sources/InceptLaunch/Services/SettingsWindowController.swift`
- Modify: `Sources/InceptLaunch/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `GlobalHotKeyManager` from Task 3 (no new methods needed here beyond what Task 3 produced).
- Produces: `GeneralSettingsView.hotKeyManager: GlobalHotKeyManager?` available for Task 5's `HotKeyRecorderRow`.

No test for this task — it's plumbing a reference through four view/controller layers with no new logic; correctness is verified by the build and by Task 5's manual check.

- [ ] **Step 1: `AppDelegate` creates the hotkey manager before `MenuBarController` and passes it in**

In `Sources/InceptLaunch/App/AppDelegate.swift`, reorder `applicationDidFinishLaunching` so `hotKeyManager` exists before `MenuBarController` is constructed, and pass it in:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Apply the user's chosen app icon to the Dock.
        let prefs = (try? PreferencesStore().load()) ?? .default
        IconSwitcher.apply(prefs.appIconStyle)
        LoginItemService.apply(prefs.launchAtLogin)
        // Hotkey must open (or toggle) and then re-assert keyboard focus —
        // Carbon hotkeys fire while another app is frontmost.
        hotKeyManager = GlobalHotKeyManager { [overlay] in
            DispatchQueue.main.async {
                overlay.toggle()
            }
        }
        hotKeyManager?.start(keyCode: prefs.hotKeyCode, modifiers: prefs.hotKeyModifiers)
        menuBarController = MenuBarController(overlay: overlay, hotKeyManager: hotKeyManager)
        // Launch straight into the full-screen launchpad overlay.
        overlay.show()
    }
```

- [ ] **Step 2: `MenuBarController` accepts and forwards the manager**

In `Sources/InceptLaunch/Services/MenuBarController.swift`, add a stored property and thread it through `init` and `openSettings`:

Replace:
```swift
    private let overlay: OverlayWindowController
    private let settings = SettingsWindowController()
```
with:
```swift
    private let overlay: OverlayWindowController
    private weak var hotKeyManager: GlobalHotKeyManager?
    private let settings = SettingsWindowController()
```

Replace:
```swift
    init(overlay: OverlayWindowController) {
        self.overlay = overlay
        super.init()
```
with:
```swift
    init(overlay: OverlayWindowController, hotKeyManager: GlobalHotKeyManager?) {
        self.overlay = overlay
        self.hotKeyManager = hotKeyManager
        super.init()
```

Replace:
```swift
    @objc private func openSettings() {
        settings.show(viewModel: overlay.exposedViewModel)
    }
```
with:
```swift
    @objc private func openSettings() {
        settings.show(viewModel: overlay.exposedViewModel, hotKeyManager: hotKeyManager)
    }
```

- [ ] **Step 3: `SettingsWindowController` accepts and forwards the manager**

In `Sources/InceptLaunch/Services/SettingsWindowController.swift`, replace:
```swift
    private var window: NSWindow?
    private weak var viewModel: LaunchpadViewModel?
    private var languageObserver: NSObjectProtocol?

    func show(viewModel: LaunchpadViewModel? = nil) {
        self.viewModel = viewModel
        if let window {
            window.title = Localizer.t("settings.title")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Localizer.t("settings.title")
        window.contentView = NSHostingView(rootView: SettingsView(viewModel: viewModel))
```
with:
```swift
    private var window: NSWindow?
    private weak var viewModel: LaunchpadViewModel?
    private weak var hotKeyManager: GlobalHotKeyManager?
    private var languageObserver: NSObjectProtocol?

    func show(viewModel: LaunchpadViewModel? = nil, hotKeyManager: GlobalHotKeyManager? = nil) {
        self.viewModel = viewModel
        self.hotKeyManager = hotKeyManager
        if let window {
            window.title = Localizer.t("settings.title")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Localizer.t("settings.title")
        window.contentView = NSHostingView(rootView: SettingsView(viewModel: viewModel, hotKeyManager: hotKeyManager))
```

- [ ] **Step 4: `SettingsView` accepts and forwards the manager to `GeneralSettingsView`**

In `Sources/InceptLaunch/Views/SettingsView.swift`, replace:
```swift
    private let preferencesStore = PreferencesStore()
    weak var viewModel: LaunchpadViewModel?
```
with:
```swift
    private let preferencesStore = PreferencesStore()
    weak var viewModel: LaunchpadViewModel?
    weak var hotKeyManager: GlobalHotKeyManager?
```

Replace:
```swift
            case .general:
                GeneralSettingsView(preferences: $preferences, onSave: savePreferences)
```
with:
```swift
            case .general:
                GeneralSettingsView(preferences: $preferences, hotKeyManager: hotKeyManager, onSave: savePreferences)
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: FAILS at this point — `GeneralSettingsView` doesn't declare a `hotKeyManager` parameter yet. That's expected; Task 5 adds it. If you want a green build checkpoint here, temporarily add `let hotKeyManager: GlobalHotKeyManager?` to `GeneralSettingsView` with no other changes, confirm `swift build` passes, then proceed straight into Task 5 which replaces the body anyway.

- [ ] **Step 6: Commit**

```bash
git add Sources/InceptLaunch/App/AppDelegate.swift Sources/InceptLaunch/Services/MenuBarController.swift Sources/InceptLaunch/Services/SettingsWindowController.swift Sources/InceptLaunch/Views/SettingsView.swift
git commit -m "feat: thread GlobalHotKeyManager reference down to Settings"
```

---

### Task 5: `HotKeyRecorderRow` — the recording UI

**Files:**
- Create: `Sources/InceptLaunch/Views/HotKeyRecorderRow.swift`
- Modify: `Sources/InceptLaunch/Views/SettingsView.swift`
- Modify: `Sources/InceptLaunch/Support/Localizer.swift`

**Interfaces:**
- Consumes: `HotKeyCapture.isValid`/`carbonModifiers`/`displayString` (Task 2), `GlobalHotKeyManager.updateHotKey` (Task 3), `UserPreferences.hotKeyCode`/`hotKeyModifiers` (Task 1).
- Produces: `HotKeyRecorderRow` view, used only by `GeneralSettingsView`.

No automated test — this is a SwiftUI view driving a live `NSEvent` monitor and a real `GlobalHotKeyManager`; correctness is verified by the manual check in Step 5 (the same category of untestable system interaction as Task 3).

- [ ] **Step 1: Add the new localization keys**

In `Sources/InceptLaunch/Support/Localizer.swift`, add four new keys next to each language's existing `"settings.hotKey"` entry (5 edits total — one per language block).

English block — replace:
```swift
        "settings.hotKey": "Global shortcut",
```
with:
```swift
        "settings.hotKey": "Global shortcut",
        "settings.hotKeyPressKeys": "Press keys…",
        "settings.hotKeyNeedsModifier": "Hold at least one modifier key (⌘⌥⌃⇧)",
        "settings.hotKeyEscReserved": "Esc is reserved to close the overlay",
        "settings.hotKeyConflict": "That combo is already used by another app — try a different one",
```

Chinese block — replace:
```swift
        "settings.hotKey": "全局快捷键",
```
with:
```swift
        "settings.hotKey": "全局快捷键",
        "settings.hotKeyPressKeys": "按下快捷键…",
        "settings.hotKeyNeedsModifier": "请至少按住一个修饰键（⌘⌥⌃⇧）",
        "settings.hotKeyEscReserved": "Esc 已保留用于关闭悬浮窗，不能作为快捷键",
        "settings.hotKeyConflict": "该组合已被其他应用占用，请换一个",
```

Japanese block — replace:
```swift
        "settings.hotKey": "グローバルショートカット",
```
with:
```swift
        "settings.hotKey": "グローバルショートカット",
        "settings.hotKeyPressKeys": "キーを押してください…",
        "settings.hotKeyNeedsModifier": "修飾キー（⌘⌥⌃⇧）を1つ以上押してください",
        "settings.hotKeyEscReserved": "Escはオーバーレイを閉じるために予約されています",
        "settings.hotKeyConflict": "この組み合わせは他のアプリで使用されています。別のキーを選んでください",
```

Korean block — replace:
```swift
        "settings.hotKey": "글로벌 단축키",
```
with:
```swift
        "settings.hotKey": "글로벌 단축키",
        "settings.hotKeyPressKeys": "키를 누르세요…",
        "settings.hotKeyNeedsModifier": "수정 키(⌘⌥⌃⇧)를 하나 이상 눌러야 합니다",
        "settings.hotKeyEscReserved": "Esc는 오버레이를 닫는 데 예약되어 있습니다",
        "settings.hotKeyConflict": "이 조합은 다른 앱에서 이미 사용 중입니다. 다른 조합을 선택하세요",
```

Russian block — replace:
```swift
        "settings.hotKey": "Глобальное сочетание клавиш",
```
with:
```swift
        "settings.hotKey": "Глобальное сочетание клавиш",
        "settings.hotKeyPressKeys": "Нажмите клавиши…",
        "settings.hotKeyNeedsModifier": "Удерживайте хотя бы одну клавишу-модификатор (⌘⌥⌃⇧)",
        "settings.hotKeyEscReserved": "Esc зарезервирован для закрытия окна",
        "settings.hotKeyConflict": "Эта комбинация уже используется другим приложением — выберите другую",
```

- [ ] **Step 2: Create `HotKeyRecorderRow`**

Create `Sources/InceptLaunch/Views/HotKeyRecorderRow.swift`:

```swift
import AppKit
import SwiftUI

/// Settings row that displays the current global hotkey and lets the user
/// record a new one. Recording captures exactly one keydown via a local
/// NSEvent monitor, validates it, and — only if `HotKeyManager.updateHotKey`
/// confirms no other app already owns that combo — persists it.
struct HotKeyRecorderRow: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    weak var hotKeyManager: GlobalHotKeyManager?
    let onCommitted: () -> Void

    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Localizer.t("settings.hotKey"))
                Spacer()
                Button(buttonTitle) {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .buttonStyle(.bordered)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onDisappear { stopRecording() }
    }

    private var buttonTitle: String {
        if isRecording { return Localizer.t("settings.hotKeyPressKeys") }
        return HotKeyCapture.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    private func startRecording() {
        errorMessage = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleCapturedKey(event)
            return nil // consume — the keystroke configures the hotkey, it doesn't type anywhere
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }

    private func handleCapturedKey(_ event: NSEvent) {
        let candidateKeyCode = UInt32(event.keyCode)
        let candidateModifiers = HotKeyCapture.carbonModifiers(from: event.modifierFlags)

        guard HotKeyCapture.isValid(keyCode: candidateKeyCode, modifiers: candidateModifiers) else {
            errorMessage = candidateModifiers == 0
                ? Localizer.t("settings.hotKeyNeedsModifier")
                : Localizer.t("settings.hotKeyEscReserved")
            stopRecording()
            return
        }

        guard let hotKeyManager, hotKeyManager.updateHotKey(keyCode: candidateKeyCode, modifiers: candidateModifiers) else {
            errorMessage = Localizer.t("settings.hotKeyConflict")
            stopRecording()
            return
        }

        errorMessage = nil
        keyCode = candidateKeyCode
        modifiers = candidateModifiers
        stopRecording()
        onCommitted()
    }
}
```

- [ ] **Step 3: Wire it into `GeneralSettingsView`**

In `Sources/InceptLaunch/Views/SettingsView.swift`, replace:
```swift
struct GeneralSettingsView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void
```
with:
```swift
struct GeneralSettingsView: View {
    @Binding var preferences: UserPreferences
    weak var hotKeyManager: GlobalHotKeyManager?
    let onSave: () -> Void
```

Replace (this is the interim placeholder Task 1 introduced to keep the build green —
`Text(...)` and no trailing `.onChange(of: preferences.hotKey)`, since Task 1 already
removed that observer):
```swift
            Section(Localizer.t("settings.launch")) {
                Text(Localizer.t("settings.hotKey"))
                Toggle(Localizer.t("settings.launchAtLogin"), isOn: $preferences.launchAtLogin)
```
with:
```swift
            Section(Localizer.t("settings.launch")) {
                HotKeyRecorderRow(
                    keyCode: $preferences.hotKeyCode,
                    modifiers: $preferences.hotKeyModifiers,
                    hotKeyManager: hotKeyManager,
                    onCommitted: onSave
                )
                Toggle(Localizer.t("settings.launchAtLogin"), isOn: $preferences.launchAtLogin)
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all tests pass (existing suite + Task 1's and Task 2's new tests).

- [ ] **Step 6: Manual verification**

1. Launch the app, open Settings → General. Confirm the hotkey row shows "⌥Space".
2. Click the button, press Cmd+Shift+K. Confirm the button now reads "⌘⇧K" and the overlay opens/closes with that combo instead of Option+Space.
3. Click the button again, press Esc. Confirm it shows the "reserved" error and the hotkey stays Cmd+Shift+K.
4. Click the button, release without pressing any modifier-bearing key (e.g. press plain "A"). Confirm it shows the "needs modifier" error and the hotkey is unchanged.
5. Quit and relaunch the app. Confirm the hotkey is still Cmd+Shift+K (persisted).

- [ ] **Step 7: Commit**

```bash
git add Sources/InceptLaunch/Views/HotKeyRecorderRow.swift Sources/InceptLaunch/Views/SettingsView.swift Sources/InceptLaunch/Support/Localizer.swift
git commit -m "feat: add hotkey recorder UI with live conflict detection"
```

---

## Self-Review Notes

- **Spec coverage:** data model (Task 1), `HotKeyCapture` validation/display (Task 2), `GlobalHotKeyManager.updateHotKey` + rollback (Task 3), plumbing (Task 4), recorder UI + all localized strings (Task 5) — every spec section has a task.
- **Type consistency:** `keyCode`/`modifiers` are `UInt32` everywhere (`UserPreferences`, `HotKeyCapture`, `GlobalHotKeyManager`, `HotKeyRecorderRow`) — no mismatched types across tasks.
- **No placeholders:** every step has literal code; the two "no automated test" tasks (3 and 5) explain why (live system API, no simulation path) rather than silently skipping tests, and each still has a concrete manual verification script.
