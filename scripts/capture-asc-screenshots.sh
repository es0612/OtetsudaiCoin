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
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro Max'
TEST_CLASS="OtetsudaiCoinUITests/ASCScreenshotUITests"
OUT_DIR="docs/screenshots/asc/v1.1.x"

TMP_ROOT="$(mktemp -d)"
RESULT_BUNDLE="$TMP_ROOT/result.xcresult"
EXTRACT_DIR="$TMP_ROOT/extracted"

echo "==> Running ASCScreenshotUITests"
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:"$TEST_CLASS" \
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
jq -r '.[].attachments[] | "\(.suggestedHumanReadableName)\t\(.exportedFileName)"' \
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
