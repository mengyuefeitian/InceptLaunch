#!/usr/bin/env bash
# Rebuild .icns at Dock-friendly visual weight and keep master PNGs in backup/.
# Runtime only needs: *.icns + thumb_*.png for the settings picker.
#
# macOS Dock masks icons; full-bleed artwork looks oversized next to system apps.
# We normalize every variant so the opaque content sits at ~CONTENT_RATIO of the
# canvas (centered), matching typical third-party Dock icons.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONS="$ROOT/Resources/Icons"
BACKUP="$ICONS/backup"
MAIN_ICNS="$ROOT/Resources/InceptLaunch.icns"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/incept-icons.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Opaque glyph / rounded-square body as a fraction of the 512 canvas.
# System apps often measure ~0.82–0.86; solid custom icons read larger, so 0.76.
CONTENT_RATIO="${CONTENT_RATIO:-0.76}"

# Cap largest layer at 512pt (omit 1024px 512@2x — biggest win for Dock-quality icons).
declare -a SIZES=(
  "icon_16x16.png:16"
  "icon_16x16@2x.png:32"
  "icon_32x32.png:32"
  "icon_32x32@2x.png:64"
  "icon_128x128.png:128"
  "icon_128x128@2x.png:256"
  "icon_256x256.png:256"
  "icon_256x256@2x.png:512"
  "icon_512x512.png:512"
  # intentionally no icon_512x512@2x.png (1024)
)

normalize_master_png() {
  # $1 = source png/icns path, $2 = output 512 RGBA png
  local src="$1"
  local out="$2"
  python3 - "$src" "$out" "$CONTENT_RATIO" <<'PY'
import sys
from PIL import Image
import numpy as np
import subprocess, tempfile, os, shutil

src, out, ratio_s = sys.argv[1], sys.argv[2], sys.argv[3]
ratio = float(ratio_s)
canvas = 512

def load(path):
    if path.lower().endswith('.icns'):
        tmp = tempfile.mkdtemp()
        try:
            iconset = os.path.join(tmp, 'x.iconset')
            r = subprocess.run(['iconutil', '-c', 'iconset', path, '-o', iconset], capture_output=True)
            best = None
            if r.returncode == 0 and os.path.isdir(iconset):
                for f in os.listdir(iconset):
                    if f.endswith('.png'):
                        im = Image.open(os.path.join(iconset, f)).convert('RGBA')
                        if best is None or im.size[0] > best.size[0]:
                            best = im
            if best is None:
                png = os.path.join(tmp, 'i.png')
                subprocess.run(['sips', '-s', 'format', 'png', path, '--out', png], check=True, capture_output=True)
                best = Image.open(png).convert('RGBA')
            return best
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    return Image.open(path).convert('RGBA')

def clean(im, thr=10):
    a = np.array(im)
    a[a[:, :, 3] < thr] = [0, 0, 0, 0]
    return Image.fromarray(a, 'RGBA')

def bbox(im, thr=8):
    a = np.array(im.split()[-1])
    ys, xs = np.where(a >= thr)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1

im = clean(load(src))
# Fully opaque masters (no alpha) cannot be auto-padded meaningfully — keep as-is crop
if im.getpixel((0, 0))[3] > 200 and im.getpixel((im.size[0] - 1, 0))[3] > 200:
    # treat whole image as content
    box = (0, 0, im.size[0], im.size[1])
else:
    box = bbox(im) or (0, 0, im.size[0], im.size[1])

content = im.crop(box)
cw, ch = content.size
side = max(cw, ch)
square = Image.new('RGBA', (side, side), (0, 0, 0, 0))
square.paste(content, ((side - cw) // 2, (side - ch) // 2), content)

target = max(1, int(round(canvas * ratio)))
scaled = square.resize((target, target), Image.Resampling.LANCZOS)
out_im = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
off = (canvas - target) // 2
out_im.paste(scaled, (off, off), scaled)
out_im = clean(out_im, 10)
out_im.save(out, 'PNG')
print(f'  normalized content_ratio≈{ratio:.2f} → {out}')
PY
}

rebuild_icns_from_png() {
  local src_png="$1"
  local out_icns="$2"
  local name
  name="$(basename "$out_icns" .icns)"
  local iconset="$WORK/${name}.iconset"
  rm -rf "$iconset"
  mkdir -p "$iconset"

  for entry in "${SIZES[@]}"; do
    local file="${entry%%:*}"
    local px="${entry##*:}"
    sips -z "$px" "$px" "$src_png" --out "$iconset/$file" >/dev/null
  done
  iconutil -c icns "$iconset" -o "$out_icns"
  echo "  → $(du -h "$out_icns" | awk '{print $1}')  $out_icns"
}

echo "Optimizing icons (CONTENT_RATIO=$CONTENT_RATIO)..."
mkdir -p "$BACKUP"

normalize_one() {
  local name="$1"   # e.g. InceptLaunch-D or icon01
  local src_icns="$2"
  local out_icns="$3"

  local master="$BACKUP/${name}.png"
  local src_for_norm=""

  # Prefer existing master PNG, else icns, else special main source
  if [ -f "$BACKUP/${name}.png" ] && [ "$name" != "InceptLaunch" ]; then
    # Re-normalize from current master (already RGBA with alpha)
    src_for_norm="$BACKUP/${name}.png"
  elif [ -f "$src_icns" ]; then
    src_for_norm="$src_icns"
  elif [ -f "$ROOT/Resources/backup/InceptLaunch-icon-source.png" ] && { [ "$name" = "InceptLaunch" ] || [ "$name" = "InceptLaunch-D" ]; }; then
    src_for_norm="$ROOT/Resources/backup/InceptLaunch-icon-source.png"
  else
    echo "  skip $name (no source)"
    return 0
  fi

  echo "$name"
  normalize_master_png "$src_for_norm" "$master"
  rebuild_icns_from_png "$master" "$out_icns"

  # Settings picker thumbnail
  sips -z 128 128 "$master" --out "$ICONS/thumb_${name}.png" >/dev/null 2>&1 || true
}

# Variant icons used by IconSwitcher
for icns in "$ICONS"/*.icns; do
  [ -f "$icns" ] || continue
  name="$(basename "$icns" .icns)"
  normalize_one "$name" "$icns" "$icns"
done

# Main app icon tracks the default D variant when present
if [ -f "$ICONS/InceptLaunch-D.icns" ]; then
  echo "InceptLaunch.icns (sync from D)"
  cp -f "$ICONS/InceptLaunch-D.icns" "$MAIN_ICNS"
  cp -f "$BACKUP/InceptLaunch-D.png" "$BACKUP/InceptLaunch-main-normalized.png" 2>/dev/null || true
elif [ -f "$MAIN_ICNS" ]; then
  normalize_one "InceptLaunch" "$MAIN_ICNS" "$MAIN_ICNS"
fi

echo
echo "Done. Masters in Resources/Icons/backup/. Ship only *.icns + thumb_*.png."
ls -lhS "$MAIN_ICNS" "$ICONS"/*.icns 2>/dev/null
