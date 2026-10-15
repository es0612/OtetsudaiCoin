#!/bin/bash
# Captures verification-only screenshots (NOT App Store Connect deliverables).
# Issue #199 (scrolled shots) + Issue #151 提案1 (light/dark inventory).
#
# Runs VerificationScreenshotUITests once per appearance, toggling the
# simulator's system appearance with `xcrun simctl ui <udid> appearance`,
# then exports the attachments from each xcresult into
#   docs/screenshots/verification/<appearance>/NN-name.png   (gitignored)
#
# Usage:
#   scripts/capture-verification-screenshots.sh [--appearance light|dark|both]
#                                               [--device "iPhone 17 Pro Max"]
#                                               [--content-size <category>]
#
#   --content-size sets the simulator's Dynamic Type size for the run (e.g.
#   accessibility-extra-extra-extra-large) and restores it on exit. Omit it to
#   leave the current size untouched. Categories: see `xcrun simctl ui`.
#
#   Each output folder also gets capture-meta.txt (content size / device /
#   iOS runtime / appearance read back from the simulator, plus commit and
#   time). compare-screenshots.sh stops when the two folders differ in those
#   conditions (Issue #256).
#
#   If some tests fail (e.g. Settings buttons pushed off-screen at AX sizes),
#   the attachments of the tests that ran are still placed, then the script
#   exits 1 after listing the failing tests (Issue #248).
#
# Requirements:
#   - Xcode 16+ (xcrun xcresulttool export attachments)
#   - jq (brew install jq)
#   - An available simulator matching --device (default: iPhone 17 Pro Max)
#
# The ASC deliverable pipeline (capture-asc-screenshots.sh / ASCScreenshotUITests)
# is intentionally untouched: verification shots never go under docs/screenshots/asc/.

set -euo pipefail

PROJECT="app/OtetsudaiCoin.xcodeproj"
SCHEME="OtetsudaiCoin"
TEST_CLASS="OtetsudaiCoinUITests/VerificationScreenshotUITests"
OUT_DIR="docs/screenshots/verification"
DEVICE_NAME="iPhone 17 Pro Max"
APPEARANCE_MODE="both"
CONTENT_SIZE=""

usage() {
  sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appearance)
      [[ $# -ge 2 ]] || { echo "error: --appearance needs a value" >&2; exit 2; }
      APPEARANCE_MODE="$2"; shift 2 ;;
    --device)
      [[ $# -ge 2 ]] || { echo "error: --device needs a value" >&2; exit 2; }
      DEVICE_NAME="$2"; shift 2 ;;
    --content-size)
      [[ $# -ge 2 ]] || { echo "error: --content-size needs a value" >&2; exit 2; }
      CONTENT_SIZE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$APPEARANCE_MODE" in
  light) APPEARANCES=(light) ;;
  dark)  APPEARANCES=(dark) ;;
  both)  APPEARANCES=(light dark) ;;
  *) echo "error: --appearance must be light|dark|both (got: $APPEARANCE_MODE)" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [[ -n "$CONTENT_SIZE" ]] && ! is_valid_content_size "$CONTENT_SIZE"; then
  echo "error: --content-size must be one of: $CONTENT_SIZES (got: $CONTENT_SIZE)" >&2
  exit 2
fi

JQ="$(resolve_jq)" || {
  echo "error: no working jq found. Install with: brew install jq" >&2
  exit 1
}
echo "==> Using jq: $JQ"

# `simctl ui appearance` must hit the same device xcodebuild uses, so we pass
# `-destination id=<udid>` (see resolve_udid in lib/common.sh).
UDID="$(resolve_udid "$DEVICE_NAME")"
[[ -n "$UDID" ]] || {
  echo "error: no available simulator named '$DEVICE_NAME'. Available iPhones:" >&2
  xcrun simctl list devices available | grep iPhone >&2 || true
  exit 1
}
echo "==> Using simulator: $DEVICE_NAME ($UDID)"

# Restore whatever appearance the simulator had before this run.
boot_and_restore_appearance_on_exit "$UDID"
if [[ -n "$CONTENT_SIZE" ]]; then
  set_content_size_and_restore_on_exit "$UDID" "$CONTENT_SIZE" || exit 1
else
  # The size persists per device, so an earlier AX run can leave it enlarged.
  echo "==> Content size: $(xcrun simctl ui "$UDID" content_size 2>/dev/null) (the simulator's current setting; pass --content-size to pin it)"
fi

TMP_ROOT="$(mktemp -d)"
echo "==> Scratch: $TMP_ROOT"

place_attachments() {
  local manifest="$1" extract_dir="$2" dest_dir="$3"
  mkdir -p "$dest_dir"
  # Clear the previous run's shots: with partial results (some tests failed),
  # stale PNGs would otherwise sit next to the new ones unnoticed.
  rm -f "$dest_dir"/*.png
  local placed=0
  while IFS=$'\t' read -r human export; do
    # digits are allowed in the name (e.g. verify-14-tutorial-child-step2);
    # the "_<index>_<UUID>.png" suffix xcresult appends starts with "_".
    if [[ "$human" =~ ^verify-([0-9]{2})-([a-z0-9-]+) ]]; then
      local num="${BASH_REMATCH[1]}" name="${BASH_REMATCH[2]}"
      cp "$extract_dir/$export" "$dest_dir/${num}-${name}.png"
      echo "  $human → $dest_dir/${num}-${name}.png"
      placed=$((placed + 1))
    else
      echo "  (skip non-verification attachment: $human)"
    fi
  done < <("$JQ" -r '.[].attachments[] | "\(.suggestedHumanReadableName)\t\(.exportedFileName)"' "$manifest")
  echo "  placed $placed PNG(s) into $dest_dir"
}

FAILED_APPEARANCES=()
for appearance in "${APPEARANCES[@]}"; do
  echo "==> [$appearance] Setting simulator appearance"
  xcrun simctl ui "$UDID" appearance "$appearance"

  result_bundle="$TMP_ROOT/$appearance.xcresult"
  log="$TMP_ROOT/$appearance.log"
  echo "==> [$appearance] Running $TEST_CLASS (log: $log)"
  set +e
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$UDID" \
    -only-testing:"$TEST_CLASS" \
    -parallel-testing-enabled NO \
    -resultBundlePath "$result_bundle" > "$log" 2>&1
  xcode_exit=$?
  set -e
  grep -E -A6 '\*\* TEST|Failing tests:' "$log" || true
  if [[ $xcode_exit -ne 0 ]] || ! grep -q '\*\* TEST SUCCEEDED \*\*' "$log"; then
    echo "error: [$appearance] xcodebuild test failed (exit=$xcode_exit). See $log" >&2
    echo "hint: xcrun xcresulttool get test-results tests --path \"$result_bundle\"" >&2
    FAILED_APPEARANCES+=("$appearance")
    # A test failure still leaves the attachments of the tests that ran, so
    # place those instead of giving up. A build failure also writes a result
    # bundle, but with no attachments — that case is caught after the export.
    if [[ ! -d "$result_bundle" ]]; then
      echo "error: [$appearance] no result bundle, nothing to export" >&2
      continue
    fi
  fi

  extract_dir="$TMP_ROOT/$appearance-extracted"
  mkdir -p "$extract_dir"
  echo "==> [$appearance] Exporting attachments"
  xcrun xcresulttool export attachments --path "$result_bundle" --output-path "$extract_dir"
  # Keep the previous run's PNGs when there is nothing new to place
  # (e.g. a build failure): place_attachments clears the folder first.
  if ! "$JQ" -e '[.[].attachments[]] | length > 0' "$extract_dir/manifest.json" >/dev/null 2>&1; then
    echo "error: [$appearance] no attachments in the result bundle (build failure?); kept $OUT_DIR/$appearance as is" >&2
    continue
  fi

  echo "==> [$appearance] Placing PNGs"
  place_attachments "$extract_dir/manifest.json" "$extract_dir" "$OUT_DIR/$appearance"
  write_capture_meta "$OUT_DIR/$appearance" "$UDID" "$DEVICE_NAME"
done

echo "==> Done. Output:"
for appearance in "${APPEARANCES[@]}"; do
  ls -la "$OUT_DIR/$appearance" 2>/dev/null || echo "  (no output for $appearance)"
done

if [[ ${#FAILED_APPEARANCES[@]} -gt 0 ]]; then
  echo "error: tests failed for: ${FAILED_APPEARANCES[*]} (PNGs above may be partial, or kept from a previous run — see the errors above)" >&2
  exit 1
fi
