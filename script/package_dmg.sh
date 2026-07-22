#!/usr/bin/env bash
set -euo pipefail

# Use swiftly-installed toolchain (CLT SwiftPM has a linking bug)
SWIFTLY_TOOLCHAIN="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin"
if [ -d "$SWIFTLY_TOOLCHAIN" ]; then
  export PATH="$SWIFTLY_TOOLCHAIN:$PATH"
fi

# Packages the assembled InceptLaunch.app into a distributable DMG.
# Mirrors the autoprint flow: stage app + Applications symlink, render a
# background, create a writable image, lay out the Finder window with
# osascript, then convert to a compressed read-only image and verify.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="InceptLaunch"
APP="$ROOT/dist/$APP_NAME.app"
PLIST="$APP/Contents/Info.plist"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")}"
DMG="$ROOT/dist/$APP_NAME-$VERSION-local.dmg"
RW_DMG="$ROOT/dist/$APP_NAME-$VERSION-local-rw.dmg"
STAGING="$ROOT/dist/dmg-staging"
MOUNT_POINT="$ROOT/dist/dmg-mount"
BACKGROUND="$STAGING/.background/background.png"

if [[ ! -d "$APP" ]]; then
  echo "Missing app bundle: $APP" >&2
  echo "Run script/build_and_run.sh --verify first." >&2
  exit 1
fi

rm -rf "$STAGING" "$MOUNT_POINT" "$RW_DMG" "$DMG"
mkdir -p "$STAGING/.background"
cp -R "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

cleanup() {
  hdiutil detach "/Volumes/$APP_NAME" >/dev/null 2>&1 || true
  rm -rf "$STAGING" "$RW_DMG"
}
trap cleanup EXIT

# Render the DMG background image (light gradient panel with instructions and
# a drag arrow between the app and the Applications folder). The swiftly
# toolchain's `swift -` JIT mode cannot resolve AppKit symbols, so compile a
# throwaway binary with swiftc, linking the macOS SDK and AppKit explicitly.
SDK_PATH="$(xcrun --show-sdk-path)"
BG_SWIFT="$STAGING/render_background.swift"
BG_BIN="$STAGING/render_background"
cat > "$BG_SWIFT" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 640, height: 420)
let image = NSImage(size: size)
image.lockFocus()

let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.93, green: 0.95, blue: 1.0, alpha: 1.0),
    ending: NSColor(calibratedRed: 0.86, green: 0.90, blue: 0.98, alpha: 1.0)
)
gradient?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: size)), angle: -90)

let title = "拖入应用程序"
let subtitle = "Drag InceptLaunch into Applications"
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.22, alpha: 1.0)
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.36, green: 0.42, blue: 0.52, alpha: 1.0)
]
(title as NSString).draw(at: NSPoint(x: 218, y: 322), withAttributes: titleAttributes)
(subtitle as NSString).draw(at: NSPoint(x: 198, y: 294), withAttributes: subtitleAttributes)

let arrow = NSBezierPath()
arrow.lineWidth = 8
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 244, y: 206))
arrow.curve(to: NSPoint(x: 397, y: 206), controlPoint1: NSPoint(x: 290, y: 260), controlPoint2: NSPoint(x: 350, y: 260))
arrow.move(to: NSPoint(x: 365, y: 238))
arrow.line(to: NSPoint(x: 399, y: 206))
arrow.line(to: NSPoint(x: 358, y: 184))
NSColor(calibratedRed: 0.24, green: 0.42, blue: 0.85, alpha: 0.9).setStroke()
arrow.stroke()

let hintAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.43, green: 0.49, blue: 0.58, alpha: 1.0)
]
if let applicationsIcon = NSImage(contentsOfFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns") {
    applicationsIcon.draw(in: NSRect(x: 432, y: 166, width: 96, height: 96), from: .zero, operation: .sourceOver, fraction: 1.0)
}
("InceptLaunch" as NSString).draw(at: NSPoint(x: 118, y: 96), withAttributes: hintAttributes)
("Applications" as NSString).draw(at: NSPoint(x: 444, y: 96), withAttributes: hintAttributes)

image.unlockFocus()
guard let data = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: data),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    exit(1)
}
try png.write(to: URL(fileURLWithPath: output))
SWIFT
swiftc -sdk "$SDK_PATH" -framework AppKit "$BG_SWIFT" -o "$BG_BIN"
"$BG_BIN" "$BACKGROUND"
rm -f "$BG_SWIFT" "$BG_BIN"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDRW -fs HFS+ "$RW_DMG" >/dev/null
attach_output="$(hdiutil attach "$RW_DMG" -readwrite)"
device="$(printf '%s\n' "$attach_output" | awk '/Apple_HFS/ {print $1}')"
volume_path="$(printf '%s\n' "$attach_output" | awk '/Apple_HFS/ {for (i=3; i<=NF; i++) {printf "%s%s", (i==3 ? "" : " "), $i}; print ""}')"
if [[ -z "${volume_path:-}" || ! -d "$volume_path" ]]; then
  volume_path="/Volumes/$APP_NAME"
fi

rm -rf "$volume_path/.fseventsd"
chflags hidden "$volume_path/.background" >/dev/null 2>&1 || true
SetFile -a V "$volume_path/.background" >/dev/null 2>&1 || true

osascript <<APPLESCRIPT
tell application "Finder"
    set volumeAlias to POSIX file "$volume_path" as alias
    tell folder volumeAlias
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {120, 120, 760, 540}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set background picture of theViewOptions to file ".background:background.png"
        try
            set position of item "$APP_NAME.app" of container window to {160, 210}
        end try
        try
            set position of item "Applications" of container window to {480, 210}
        end try
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

rm -rf "$volume_path/.fseventsd"
chflags hidden "$volume_path/.background" >/dev/null 2>&1 || true
SetFile -a V "$volume_path/.background" >/dev/null 2>&1 || true
sync
hdiutil detach "$device" >/dev/null
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
hdiutil verify "$DMG"
trap - EXIT
cleanup
echo "$DMG"
