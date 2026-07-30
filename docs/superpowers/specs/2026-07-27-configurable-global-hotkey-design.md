# Configurable Global Hotkey

## Problem

`GlobalHotKeyManager` hardcodes Option+Space as the overlay toggle
(`Sources/iLaunch/Services/GlobalHotKeyManager.swift`). `UserPreferences.hotKey`
is a `String` bound to a `TextField` in Settings, but it is never parsed or fed
back into the manager — it's dead UI. Users cannot change the hotkey, and there
is no conflict detection against other apps that may already own the same
system-wide shortcut.

## Goals

- Let the user record a new global hotkey from Settings.
- Detect when the chosen combo is already registered by another app and
  reject it with a clear error, without disturbing the currently active
  hotkey.
- Reject unusable combos up front: no modifier key at all, or Esc (reserved
  to close the overlay).
- Preserve today's behavior (Option+Space) for existing users after upgrade.

## Non-goals

- Enumerating or displaying *what* other app owns a conflicting hotkey — Carbon
  only reports that registration failed, not who holds it.
- Detecting conflicts with hotkeys registered via other mechanisms (e.g.
  `CGEventTap`/Accessibility-based global monitors that don't go through
  `RegisterEventHotKey`). Those can't collide at the Carbon API level, so
  there's nothing to detect; this is a known, accepted gap.

## Data model

`UserPreferences.hotKey: String` is removed and replaced with:

```swift
var hotKeyCode: UInt32       // Carbon virtual keycode, e.g. kVK_Space (49)
var hotKeyModifiers: UInt32  // Carbon modifier mask, e.g. optionKey (2048)
```

Defaults (`UserPreferences.default` and the decode fallback) are `49` /
`2048` — today's Option+Space — so existing installs see no behavior change
after upgrade. Follows the existing `(try? c.decodeIfPresent(...)) ?? default`
pattern already used for every other field added after v1.0.

## Components

### `GlobalHotKeyManager`

Add:

```swift
/// Unregisters the current hotkey (if any) and registers the new one.
/// Returns `false` (and leaves the previous hotkey active) if the new
/// combo is already taken by another app's Carbon-registered hotkey.
func updateHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool
```

Internally: unregister the existing `hotKeyRef` (if set), call
`RegisterEventHotKey` with the new keycode/modifiers, check the returned
`OSStatus`. Non-zero (in practice `eventHotKeyExistsErr`) means the combo is
taken — leave `hotKeyRef` nil and re-register the previous combo so the
overlay toggle keeps working, then return `false`. Zero means success —
store the new `hotKeyRef` and return `true`.

`start()` becomes `start(keyCode:modifiers:)`, called once at launch with the
stored preference instead of the hardcoded constants.

### `HotKeyCapture` (new, pure logic — unit tested)

```swift
enum HotKeyCapture {
    /// True if this keycode/modifier combo is legal to register: at least
    /// one modifier key held, and not bare Esc (reserved to close the
    /// overlay).
    static func isValid(keyCode: UInt32, modifiers: UInt32) -> Bool

    /// Human-readable label for display, e.g. "⌥Space", "⌘⇧K".
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String
}
```

### Settings UI

`GeneralSettingsView` (`SettingsView.swift`) replaces the dead `TextField`
with:

- A label showing `HotKeyCapture.displayString(...)` for the current
  preference.
- A "记录快捷键" button. Clicking flips it into a recording state (retitled
  "按下快捷键…") and installs a one-shot local `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`
  monitor.
- On the next keyDown: translate `event.keyCode` +
  `event.modifierFlags` → Carbon keycode/modifier values, remove the
  monitor, and validate with `HotKeyCapture.isValid`.
  - Invalid (no modifier / Esc) → show inline error "请至少按住一个修饰键" /
    "Esc 不能作为快捷键", stay out of recording state, keep old hotkey.
  - Valid → call `hotKeyManager.updateHotKey(keyCode:modifiers:)`.
    - `true` → persist `hotKeyCode`/`hotKeyModifiers` to preferences, save,
      update the displayed label.
    - `false` → show inline error "该组合已被其他应用占用，请换一个", keep the
      old hotkey active and persisted (no save).

`OverlayWindowController`/`AppDelegate` wiring: `AppDelegate` reads
`hotKeyCode`/`hotKeyModifiers` from preferences and passes them to
`GlobalHotKeyManager.start(keyCode:modifiers:)`. Settings needs a reference to
the live `GlobalHotKeyManager` instance (currently owned by `AppDelegate`) to
call `updateHotKey` — passed down the same way `viewModel` already is for
`AppManagementSettingsView`.

## Testing

- `HotKeyCaptureTests`: `isValid` rejects no-modifier and bare-Esc combos,
  accepts e.g. Option+Space and Cmd+Shift+K; `displayString` renders expected
  symbols for a few representative combos.
- `UserPreferences` round-trip test: encode/decode preserves
  `hotKeyCode`/`hotKeyModifiers`; decoding a legacy JSON blob missing those
  keys falls back to the Option+Space default.
- `GlobalHotKeyManager.updateHotKey` is not unit tested: it's a thin wrapper
  around a live Carbon/system API tied to a process-wide event target, and
  there's no way to simulate "another process already holds this exact
  hotkey" in an automated test. The success path (register a fresh combo,
  confirm the overlay still toggles) and the rollback path (attempt to
  re-register the same combo twice from two manager instances, confirming
  the second returns `false` and the first keeps working) will be verified
  manually before release.

## Migration / compatibility

No `hotKey` string field remains after this change — its removal from
`CodingKeys` means old JSON preference files simply ignore the leftover key
on decode (extra keys are not an error for `Decodable`). No explicit
migration code needed.
