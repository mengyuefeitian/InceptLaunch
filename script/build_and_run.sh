#!/usr/bin/env bash
set -euo pipefail

# Use swiftly-installed toolchain (CLT SwiftPM has a linking bug)
SWIFTLY_TOOLCHAIN="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin"
if [ -d "$SWIFTLY_TOOLCHAIN" ]; then
  export PATH="$SWIFTLY_TOOLCHAIN:$PATH"
fi

MODE="${1:-run}"
APP_NAME="InceptLaunch"
BUNDLE_ID="com.inceptlaunch.InceptLaunch"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
# pkill returns immediately after sending SIGTERM; wait for the process to
# actually exit before rebuilding/relaunching, so an old instance's in-flight
# bootstrapScan()/persistLayout() can never race a new instance's on the same
# layout.json (two separate processes — in-process serialization can't help).
for _ in $(seq 1 50); do
  pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
  sleep 0.1
done

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

APP_RESOURCES="$APP_CONTENTS/Resources"
ICON_SOURCE="$ROOT_DIR/Resources/$APP_NAME.icns"
mkdir -p "$APP_RESOURCES"
if [ -f "$ICON_SOURCE" ]; then
  cp "$ICON_SOURCE" "$APP_RESOURCES/$APP_NAME.icns"
fi
# Runtime icons only: optimized .icns + small thumb_*.png for settings picker.
# Full-size source PNGs live in Resources/Icons/backup/ and are not packaged.
if [ -d "$ROOT_DIR/Resources/Icons" ]; then
  cp "$ROOT_DIR/Resources/Icons/"*.icns "$APP_RESOURCES/" 2>/dev/null || true
  cp "$ROOT_DIR/Resources/Icons/"thumb_*.png "$APP_RESOURCES/" 2>/dev/null || true
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>1.7.9</string>
  <key>CFBundleVersion</key>
  <string>1.7.9</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc sign the bundle for local distribution (no Developer ID / notarization).
codesign --force --deep --sign - "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

# --verify launches straight from the binary (not `open`, which does not
# forward env vars to the launched app) with INCEPTLAUNCH_DATA_DIR pointed at
# a throwaway directory. A prior incident had automated verify runs pointed
# at the user's real ~/Library/Application Support/InceptLaunch and coincided
# with the user's real layout.json losing custom folders — root cause was
# never fully confirmed, but there is no reason automated verification needs
# real data, so this removes the whole risk class. Use `run` (real `open`,
# real data dir) for actual interactive use.
open_app_isolated() {
  local data_dir
  data_dir="$(mktemp -d "${TMPDIR:-/tmp}/inceptlaunch-verify.XXXXXX")"
  echo "verify data dir: $data_dir"
  # Redirect the backgrounded GUI process's own stdout/stderr away from this
  # script's fds — otherwise a caller piping this script's output (e.g. to
  # `tail`) blocks forever waiting for EOF, since the long-lived app process
  # holds the pipe open.
  INCEPTLAUNCH_DATA_DIR="$data_dir" nohup "$APP_BINARY" >/dev/null 2>&1 &
  disown
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
    open_app_isolated
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
