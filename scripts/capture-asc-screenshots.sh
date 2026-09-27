#!/bin/bash
# Captures ASC localization screenshots for Issue #50 Phase 1 § 1.5.
#
# Runs ASCScreenshotUITests, exports attachments from the xcresult bundle,
# and places renamed PNGs into docs/screenshots/asc/v1.1.x/{ja,en}/.
#
# Requirements:
#   - Xcode 16+ (xcrun xcresulttool export attachments)
#   - jq (brew install jq)
#   - An available iPhone 17 Pro Max simulator (6.7-inch, ASC max-size device)

set -euo pipefail

PROJECT="app/OtetsudaiCoin.xcodeproj"
SCHEME="OtetsudaiCoin"
DEVICE_NAME="iPhone 17 Pro Max"
TEST_CLASS="OtetsudaiCoinUITests/ASCScreenshotUITests"
OUT_DIR="docs/screenshots/asc/v1.1.x"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Resolve a working jq before the slow xcodebuild (fail fast).
JQ="$(resolve_jq)" || {
  echo "error: no working jq found. Install with: brew install jq" >&2
  exit 1
}
echo "==> Using jq: $JQ"

UDID="$(resolve_udid "$DEVICE_NAME")"
[[ -n "$UDID" ]] || {
  echo "error: no available simulator named '$DEVICE_NAME'. Available iPhones:" >&2
  xcrun simctl list devices available | grep iPhone >&2 || true
  exit 1
}
echo "==> Using simulator: $DEVICE_NAME ($UDID)"

# ASC deliverables are always light. Force it for this run only and restore
# the developer's own setting on exit — otherwise a simulator left in dark
# silently produces dark ASC screenshots. See Issue #218.
boot_and_restore_appearance_on_exit "$UDID"
echo "==> Forcing light appearance for ASC capture"
xcrun simctl ui "$UDID" appearance light

TMP_ROOT="$(mktemp -d)"
RESULT_BUNDLE="$TMP_ROOT/result.xcresult"
EXTRACT_DIR="$TMP_ROOT/extracted"

echo "==> Running ASCScreenshotUITests"
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -only-testing:"$TEST_CLASS" \
  -parallel-testing-enabled NO \
  -resultBundlePath "$RESULT_BUNDLE" \
  | tail -20

echo "==> Exporting attachments from xcresult"
mkdir -p "$EXTRACT_DIR"
xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$EXTRACT_DIR"

echo "==> Renaming and placing PNGs into $OUT_DIR"
mkdir -p "$OUT_DIR/ja" "$OUT_DIR/en"

# manifest.json schema:
#   [ { "testIdentifier": "...", "attachments": [
#     { "exportedFileName": "...", "suggestedHumanReadableName": "ja-01-home", ... }
#   ] } ]
"$JQ" -r '.[].attachments[] | "\(.suggestedHumanReadableName)\t\(.exportedFileName)"' \
   "$EXTRACT_DIR/manifest.json" \
  | while IFS=$'\t' read -r human export; do
      if [[ "$human" =~ ^(ja|en)-([0-9]{2})-([a-z]+) ]]; then
        lang="${BASH_REMATCH[1]}"
        num="${BASH_REMATCH[2]}"
        name="${BASH_REMATCH[3]}"
        dest="$OUT_DIR/$lang/${num}-${name}.png"
        cp "$EXTRACT_DIR/$export" "$dest"
        echo "  $human → $dest"
      else
        echo "  (skip non-screenshot attachment: $human)"
      fi
    done

echo "==> Done. Output:"
ls -la "$OUT_DIR/ja" "$OUT_DIR/en"
