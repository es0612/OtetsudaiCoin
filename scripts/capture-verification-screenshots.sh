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

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appearance)
      [[ $# -ge 2 ]] || { echo "error: --appearance needs a value" >&2; exit 2; }
      APPEARANCE_MODE="$2"; shift 2 ;;
    --device)
      [[ $# -ge 2 ]] || { echo "error: --device needs a value" >&2; exit 2; }
      DEVICE_NAME="$2"; shift 2 ;;
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

# Same resolution strategy as capture-asc-screenshots.sh (kept in sync by hand):
# the asdf shim can be first in PATH but broken, so run --version to confirm.
resolve_jq() {
  local candidate
  for candidate in "${JQ:-}" /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
    { [ -n "$candidate" ] && [ -x "$candidate" ]; } || continue
    if "$candidate" --version >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if command -v jq >/dev/null 2>&1 && jq --version >/dev/null 2>&1; then
    command -v jq
    return 0
  fi
  return 1
}

JQ="$(resolve_jq)" || {
  echo "error: no working jq found. Install with: brew install jq" >&2
  exit 1
}
echo "==> Using jq: $JQ"

# Resolve ONE udid for the device name. Several simulators can share a name
# (this machine has 7× "iPhone 17 Pro Max"); `simctl ui appearance` must hit
# the same device xcodebuild uses, so we pass `-destination id=<udid>`.
# Prefer an already-booted one to skip boot time.
resolve_udid() {
  local name="$1"
  xcrun simctl list devices available -j \
    | "$JQ" -r --arg n "$name" '
        [.devices[][] | select(.name == $n and .isAvailable)]
        | sort_by(.state != "Booted")
        | .[0].udid // empty'
}

UDID="$(resolve_udid "$DEVICE_NAME")"
[[ -n "$UDID" ]] || {
  echo "error: no available simulator named '$DEVICE_NAME'. Available iPhones:" >&2
  xcrun simctl list devices available | grep iPhone >&2 || true
  exit 1
}
echo "==> Using simulator: $DEVICE_NAME ($UDID)"

# Always leave the simulator in light mode, even if a run fails midway.
restore_appearance() {
  xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1 || true
}
trap restore_appearance EXIT

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true   # no-op if already booted
xcrun simctl bootstatus "$UDID" -b >/dev/null

TMP_ROOT="$(mktemp -d)"
echo "==> Scratch: $TMP_ROOT"

place_attachments() {
  local manifest="$1" extract_dir="$2" dest_dir="$3"
  mkdir -p "$dest_dir"
  local placed=0
  while IFS=$'\t' read -r human export; do
    if [[ "$human" =~ ^verify-([0-9]{2})-([a-z-]+) ]]; then
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
    exit 1
  fi

  extract_dir="$TMP_ROOT/$appearance-extracted"
  mkdir -p "$extract_dir"
  echo "==> [$appearance] Exporting attachments"
  xcrun xcresulttool export attachments --path "$result_bundle" --output-path "$extract_dir"

  echo "==> [$appearance] Placing PNGs"
  place_attachments "$extract_dir/manifest.json" "$extract_dir" "$OUT_DIR/$appearance"
done

echo "==> Done. Output:"
for appearance in "${APPEARANCES[@]}"; do
  ls -la "$OUT_DIR/$appearance"
done
