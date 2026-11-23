#!/bin/bash
# Captures verification-only screenshots (NOT App Store Connect deliverables).
# Issue #199 (scrolled shots) + Issue #151 提案1 (light/dark inventory).
#
# Runs VerificationScreenshotUITests once per appearance, toggling the
# simulator's system appearance with `xcrun simctl ui <udid> appearance`,
# then exports the attachments from each xcresult into
#   docs/screenshots/verification/<appearance>/NN-name.png      (ja, gitignored)
#   docs/screenshots/verification/en/<appearance>/NN-name.png   (en, gitignored)
#
# Usage:
#   scripts/capture-verification-screenshots.sh [--appearance light|dark|both]
#                                               [--locale ja|en|both]
#                                               [--device "iPhone 17 Pro Max"]
#                                               [--content-size <category>]
#
#   --locale picks the app language (default: ja). It reaches the UI tests as
#   VERIFY_LOCALE through TEST_RUNNER_VERIFY_LOCALE (see TEST_RUNNER_<VAR> in
#   `man xcodebuild`). en captures only the scenes that find their buttons by
#   identifier: 01-08 and 31-34, plus the tutorial scenes (00, 12, 14-19,
#   23-25), which use tutorial-only accessibility identifiers. The tests that
#   look buttons up by Japanese text are skipped in en (Issues #309, #308).
#
#   --content-size sets the simulator's Dynamic Type size for the run (e.g.
#   accessibility-extra-extra-extra-large) and restores it on exit. Omit it to
#   leave the current size untouched. Categories: see `xcrun simctl ui`.
#
#   Each output folder also gets capture-meta.txt (content size / device /
#   iOS runtime / appearance / Reduce Motion read back from the simulator,
#   plus commit and time). compare-screenshots.sh stops when the two folders
#   differ in those conditions (Issue #256, #283).
#
#   While each run is in progress, the script re-reads appearance / content
#   size / Reduce Motion every 5 seconds. If another session changes any of
#   them on the same simulator (even if it changes them back), that run's
#   shots are discarded, the folder keeps the previous shots, and the script
#   exits 1 (Issue #283).
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
LOCALE_MODE="ja"
CONTENT_SIZE=""

# Prints the header comment: from the line after the shebang up to the first
# non-comment line, so the usage grows with the header (no fixed line range).
usage() {
  awk 'NR == 1 { next } !/^#/ { exit } { print }' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appearance)
      [[ $# -ge 2 ]] || { echo "error: --appearance needs a value" >&2; exit 2; }
      APPEARANCE_MODE="$2"; shift 2 ;;
    --locale)
      [[ $# -ge 2 ]] || { echo "error: --locale needs a value" >&2; exit 2; }
      LOCALE_MODE="$2"; shift 2 ;;
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

case "$LOCALE_MODE" in
  ja)   LOCALES=(ja) ;;
  en)   LOCALES=(en) ;;
  both) LOCALES=(ja en) ;;
  *) echo "error: --locale must be ja|en|both (got: $LOCALE_MODE)" >&2; exit 2 ;;
esac

# ja keeps the original paths so existing before/after folders stay comparable.
locale_out_dir() {
  local appearance="$1" locale="$2"
  if [[ "$locale" == "ja" ]]; then
    echo "$OUT_DIR/$appearance"
  else
    echo "$OUT_DIR/$locale/$appearance"
  fi
}

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

FAILED_RUNS=()
for appearance in "${APPEARANCES[@]}"; do
  echo "==> [$appearance] Setting simulator appearance"
  xcrun simctl ui "$UDID" appearance "$appearance"

  for locale in "${LOCALES[@]}"; do
    run="$appearance/$locale"
    dest_dir="$(locale_out_dir "$appearance" "$locale")"
    result_bundle="$TMP_ROOT/$appearance-$locale.xcresult"
    log="$TMP_ROOT/$appearance-$locale.log"
    watch_log="$TMP_ROOT/$appearance-$locale.conditions.log"
    echo "==> [$run] Watching simulator settings during the run: $(read_sim_conditions "$UDID")"
    start_condition_watch "$UDID" "$watch_log"
    echo "==> [$run] Running $TEST_CLASS (log: $log)"
    set +e
    TEST_RUNNER_VERIFY_LOCALE="$locale" xcodebuild test \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "id=$UDID" \
      -only-testing:"$TEST_CLASS" \
      -parallel-testing-enabled NO \
      -resultBundlePath "$result_bundle" > "$log" 2>&1
    xcode_exit=$?
    set -e
    stop_condition_watch
    grep -E -A6 '\*\* TEST|Failing tests:' "$log" || true
    # Another session may have changed the shared simulator mid-run (Issue #283).
    # Those shots cannot be trusted, so place nothing and keep the previous ones.
    if [[ -s "$watch_log" ]]; then
      echo "error: [$run] simulator settings changed during the run (another session using the same device?):" >&2
      sed 's/^/  /' "$watch_log" >&2
      echo "error: [$run] discarded this run's shots; kept $dest_dir as is. Check the settings and capture again." >&2
      FAILED_RUNS+=("$run")
      continue
    fi
    if [[ $xcode_exit -ne 0 ]] || ! grep -q '\*\* TEST SUCCEEDED \*\*' "$log"; then
      echo "error: [$run] xcodebuild test failed (exit=$xcode_exit). See $log" >&2
      echo "hint: xcrun xcresulttool get test-results tests --path \"$result_bundle\"" >&2
      FAILED_RUNS+=("$run")
      # A test failure still leaves the attachments of the tests that ran, so
      # place those instead of giving up. A build failure also writes a result
      # bundle, but with no attachments — that case is caught after the export.
      if [[ ! -d "$result_bundle" ]]; then
        echo "error: [$run] no result bundle, nothing to export" >&2
        continue
      fi
    fi

    extract_dir="$TMP_ROOT/$appearance-$locale-extracted"
    mkdir -p "$extract_dir"
    echo "==> [$run] Exporting attachments"
    xcrun xcresulttool export attachments --path "$result_bundle" --output-path "$extract_dir"
    # Keep the previous run's PNGs when there is nothing new to place
    # (e.g. a build failure): place_attachments clears the folder first.
    if ! "$JQ" -e '[.[].attachments[]] | length > 0' "$extract_dir/manifest.json" >/dev/null 2>&1; then
      echo "error: [$run] no attachments in the result bundle (build failure?); kept $dest_dir as is" >&2
      continue
    fi

    echo "==> [$run] Placing PNGs"
    place_attachments "$extract_dir/manifest.json" "$extract_dir" "$dest_dir"
    write_capture_meta "$dest_dir" "$UDID" "$DEVICE_NAME" "$locale"
  done
done

echo "==> Done. Output:"
for appearance in "${APPEARANCES[@]}"; do
  for locale in "${LOCALES[@]}"; do
    dest_dir="$(locale_out_dir "$appearance" "$locale")"
    ls -la "$dest_dir" 2>/dev/null || echo "  (no output for $appearance/$locale)"
  done
done

if [[ ${#FAILED_RUNS[@]} -gt 0 ]]; then
  echo "error: tests failed for: ${FAILED_RUNS[*]} (PNGs above may be partial, or kept from a previous run — see the errors above)" >&2
  exit 1
fi
