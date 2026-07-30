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

# Render the DMG background image (gradient + titles + a single curved arrow).
# Do NOT paint app/Applications icons or labels here — Finder places the real
# items; drawing them on the background causes double icons and overflow.
# The swiftly toolchain's `swift -` JIT mode cannot resolve AppKit symbols, so
# compile a throwaway binary with swiftc, linking the macOS SDK and AppKit.
SDK_PATH="$(xcrun --show-sdk-path)"
BG_SWIFT="$STAGING/render_background.swift"
BG_BIN="$STAGING/render_background"
cat > "$BG_SWIFT" <<'SWIFT'
import AppKit
import Foundation

let output = CommandLine.arguments[1]
// Window content size matches Finder bounds width/height below (640×420).
let size = NSSize(width: 640, height: 420)
let image = NSImage(size: size)
image.lockFocus()

// y increases upward in AppKit image coordinates.
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
// Center titles horizontally.
let titleSize = (title as NSString).size(withAttributes: titleAttributes)
let subtitleSize = (subtitle as NSString).size(withAttributes: subtitleAttributes)
(title as NSString).draw(
    at: NSPoint(x: (size.width - titleSize.width) / 2, y: 322),
    withAttributes: titleAttributes
)
(subtitle as NSString).draw(
    at: NSPoint(x: (size.width - subtitleSize.width) / 2, y: 294),
    withAttributes: subtitleAttributes
)

// Curved arrow between the two icon slots (icon centers ~160 and ~480 in Finder).
// Arc runs left → right with a slight arch; filled arrowhead follows end tangent.
let start = CGPoint(x: 248, y: 200)
let tip = CGPoint(x: 392, y: 200)
let cp1 = CGPoint(x: 298, y: 258)
let cp2 = CGPoint(x: 338, y: 258)

// Tangent at t=1 of cubic Bezier ≈ (tip - cp2)
var tx = tip.x - cp2.x
var ty = tip.y - cp2.y
let tlen = max(0.001, hypot(tx, ty))
tx /= tlen
ty /= tlen
let px = -ty
let py = tx

let headLen: CGFloat = 26
let headHalf: CGFloat = 13
// Stop the shaft inside the head so the round line-cap does not stick out.
let shaftEnd = CGPoint(x: tip.x - tx * (headLen * 0.55), y: tip.y - ty * (headLen * 0.55))

let stroke = NSColor(calibratedRed: 0.24, green: 0.42, blue: 0.85, alpha: 0.92)

let shaft = NSBezierPath()
shaft.lineWidth = 7
shaft.lineCapStyle = .round
shaft.lineJoinStyle = .round
shaft.move(to: start)
shaft.curve(to: shaftEnd, controlPoint1: cp1, controlPoint2: cp2)
stroke.setStroke()
shaft.stroke()

let base = CGPoint(x: tip.x - tx * headLen, y: tip.y - ty * headLen)
let left = CGPoint(x: base.x + px * headHalf, y: base.y + py * headHalf)
let right = CGPoint(x: base.x - px * headHalf, y: base.y - py * headHalf)
let head = NSBezierPath()
head.move(to: tip)
head.line(to: left)
head.line(to: right)
head.close()
stroke.setFill()
head.fill()

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

rm -rf "$volume_path/.fseventsd" "$volume_path/.Spotlight-V100" "$volume_path/.Trashes" 2>/dev/null || true
# Hide support folder from Finder (flag + invisible name flag).
chflags hidden "$volume_path/.background" >/dev/null 2>&1 || true
if command -v SetFile >/dev/null 2>&1; then
  SetFile -a V "$volume_path/.background" >/dev/null 2>&1 || true
fi

osascript <<APPLESCRIPT
tell application "Finder"
    set volumeAlias to POSIX file "$volume_path" as alias
    tell folder volumeAlias
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- 640×420 content area (matches background.png)
        set bounds of container window to {120, 120, 760, 540}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set text size of theViewOptions to 12
        set background picture of theViewOptions to file ".background:background.png"
        -- Icon positions: centers aligned under the arrow (Finder coords, top-left origin).
        try
            set position of item "$APP_NAME.app" of container window to {160, 210}
        end try
        try
            set position of item "Applications" of container window to {480, 210}
        end try
        -- Park .background off-screen (bottom-right outside the window) so it
        -- never appears as a visible folder even if hidden flags fail.
        try
            set position of item ".background" of container window to {1200, 900}
        end try
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

rm -rf "$volume_path/.fseventsd" "$volume_path/.Spotlight-V100" "$volume_path/.Trashes" 2>/dev/null || true
chflags hidden "$volume_path/.background" >/dev/null 2>&1 || true
if command -v SetFile >/dev/null 2>&1; then
  SetFile -a V "$volume_path/.background" >/dev/null 2>&1 || true
fi
# Re-apply off-screen position after flags (Finder may re-layout).
osascript <<APPLESCRIPT
tell application "Finder"
    try
        set volumeAlias to POSIX file "$volume_path" as alias
        tell folder volumeAlias
            open
            try
                set position of item ".background" of container window to {1200, 900}
            end try
            try
                set position of item "$APP_NAME.app" of container window to {160, 210}
            end try
            try
                set position of item "Applications" of container window to {480, 210}
            end try
            delay 1
            close
        end tell
    end try
end tell
APPLESCRIPT
sync
hdiutil detach "$device" >/dev/null
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
hdiutil verify "$DMG"
trap - EXIT
cleanup
echo "$DMG"
