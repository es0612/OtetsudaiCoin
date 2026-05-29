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

# Resolve a working jq before the slow xcodebuild (fail fast). On this
# project's dev machines an asdf shim can be first in PATH
# (~/.asdf/shims/jq) but broken when its libexec is missing, so checking
# `-x` is not enough — run `--version` to confirm the binary executes.
# Honors a JQ override and covers both Homebrew prefixes (Apple Silicon /
# Intel) plus /usr/bin. See Issue #96.
resolve_jq() {
  local candidate
  for candidate in "${JQ:-}" /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
    { [ -n "$candidate" ] && [ -x "$candidate" ]; } || continue
    if "$candidate" --version >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  # Last resort: whatever `jq` resolves to on PATH, if it actually runs.
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
