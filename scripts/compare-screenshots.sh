#!/bin/bash
# Compares two directories of screenshots pixel by pixel (Issue #248).
#
# For every PNG in <before-dir> that also exists in <after-dir>, reports:
#   identical          — every pixel matches
#   status-bar-only    — pixels differ only in the top <status-bar-px> rows
#                        (the clock / battery change between captures)
#   differs y=A..B     — pixels differ below the status bar (rows A..B)
#   size-differs       — the images have different dimensions
#   missing in <after> — the PNG exists only in <before-dir>
#   extra in <after>   — the PNG exists only in <after-dir>
#
# A missing or extra file fails the comparison: with partial captures (some
# tests failed) the after side can silently have fewer shots.
#
# Use it to back a "default-size visuals are unchanged" claim with evidence:
# capture before (origin/main) and after (the branch) with
# capture-verification-screenshots.sh, then compare the two output folders.
#
# Scenes that differ between two captures of the SAME code (measured
# 2026-10-11): 03-record-scrolled / 05-settings-scrolled (the swipeUp scroll
# distance varies) and 09-task-management (the AdMob test banner). A "differs"
# there is not evidence of a regression unless the change touches that screen.
#
# Usage:
#   scripts/compare-screenshots.sh <before-dir> <after-dir> [--status-bar-px N]
#
#   --status-bar-px  rows from the top treated as status bar (default 200 =
#                    the iPhone 17 Pro Max status bar at 3x; the clock is at
#                    y=78..117)
#
# Exit: 0 if every compared pair is identical or status-bar-only and both
# folders hold the same file names; 1 if any pair differs, a file is missing or
# extra, or no pair was compared; 2 on usage errors.
# Requirements: macOS `sips` and /usr/bin/python3 (no third-party packages).

set -euo pipefail

usage() {
  sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'
}

STATUS_BAR_PX=200
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status-bar-px)
      [[ $# -ge 2 ]] || { echo "error: --status-bar-px needs a value" >&2; exit 2; }
      STATUS_BAR_PX="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    -*)
      echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
  esac
done

if [[ ${#POSITIONAL[@]} -ne 2 ]]; then
  echo "error: need <before-dir> and <after-dir>" >&2; usage >&2; exit 2
fi
BEFORE_DIR="${POSITIONAL[0]}"
AFTER_DIR="${POSITIONAL[1]}"
for dir in "$BEFORE_DIR" "$AFTER_DIR"; do
  [[ -d "$dir" ]] || { echo "error: not a directory: $dir" >&2; exit 2; }
done
[[ "$STATUS_BAR_PX" =~ ^[0-9]+$ ]] || { echo "error: --status-bar-px must be a number (got: $STATUS_BAR_PX)" >&2; exit 2; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

compared=0
differs=0
unmatched=0
for before in "$BEFORE_DIR"/*.png; do
  [[ -e "$before" ]] || break
  name="$(basename "$before")"
  after="$AFTER_DIR/$name"
  if [[ ! -e "$after" ]]; then
    echo "$name: missing in $AFTER_DIR"
    unmatched=$((unmatched + 1))
    continue
  fi
  # sips writes uncompressed BMP, so the bytes are the pixels (PNG bytes differ
  # with compression even when the pixels match).
  sips -s format bmp "$before" --out "$TMP_DIR/before.bmp" >/dev/null
  sips -s format bmp "$after" --out "$TMP_DIR/after.bmp" >/dev/null
  verdict="$(/usr/bin/python3 -I - "$TMP_DIR/before.bmp" "$TMP_DIR/after.bmp" "$STATUS_BAR_PX" <<'PY'
import struct, sys

def load(path):
    data = open(path, "rb").read()
    offset = struct.unpack("<I", data[10:14])[0]
    width, height = struct.unpack("<ii", data[18:26])
    bpp = struct.unpack("<H", data[28:30])[0]
    return data, offset, width, height, bpp

a, off, w, h, bpp = load(sys.argv[1])
b, off_b, w_b, h_b, bpp_b = load(sys.argv[2])
status_bar = int(sys.argv[3])
if (w, h, bpp) != (w_b, h_b, bpp_b):
    print("size-differs %dx%d vs %dx%d" % (w, abs(h), w_b, abs(h_b)))
    sys.exit(0)
stride = ((w * bpp // 8 + 3) // 4) * 4
rows = abs(h)
diff_rows = []
for r in range(rows):
    start = off + r * stride
    if a[start:start + stride] != b[start:start + stride]:
        # negative height = top-down rows; positive = bottom-up
        diff_rows.append(r if h < 0 else rows - 1 - r)
if not diff_rows:
    print("identical")
elif max(diff_rows) < status_bar:
    print("status-bar-only y=%d..%d" % (min(diff_rows), max(diff_rows)))
else:
    below = [y for y in diff_rows if y >= status_bar]
    print("differs y=%d..%d (%d rows below the status bar)" % (min(below), max(below), len(below)))
PY
)"
  echo "$name: $verdict"
  compared=$((compared + 1))
  case "$verdict" in
    identical|status-bar-only*) ;;
    *) differs=$((differs + 1)) ;;
  esac
done

for after in "$AFTER_DIR"/*.png; do
  [[ -e "$after" ]] || break
  name="$(basename "$after")"
  if [[ ! -e "$BEFORE_DIR/$name" ]]; then
    echo "$name: extra in $AFTER_DIR"
    unmatched=$((unmatched + 1))
  fi
done

echo "==> compared $compared pair(s), $differs differ below the status bar, $unmatched missing/extra"
if [[ $compared -eq 0 ]]; then
  echo "error: no PNG pairs to compare" >&2
  exit 1
fi
[[ $differs -eq 0 && $unmatched -eq 0 ]]
