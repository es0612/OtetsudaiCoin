# shellcheck shell=bash
# Shared helpers for the screenshot capture scripts
# (capture-asc-screenshots.sh / capture-verification-screenshots.sh).
# Source it via ${BASH_SOURCE[0]} so it resolves regardless of the caller's cwd:
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=lib/common.sh
#   source "$SCRIPT_DIR/lib/common.sh"
#
# See Issue #220.

# Prints a working jq path. On this project's dev machines an asdf shim can be
# first in PATH (~/.asdf/shims/jq) but broken when its libexec is missing, so
# checking `-x` is not enough — run `--version` to confirm the binary executes.
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

# Prints ONE udid for the device name. Several simulators can share a name
# (this project's dev machine has 7× "iPhone 17 Pro Max"), and with a `name=`
# destination xcodebuild picks among them non-deterministically, so callers
# pass `-destination id=<udid>`. Prefers an already-booted one to skip boot
# time. Requires $JQ (call resolve_jq first). See Issue #217.
resolve_udid() {
  local name="$1"
  xcrun simctl list devices available -j \
    | "$JQ" -r --arg n "$name" '
        [.devices[][] | select(.name == $n and .isAvailable)]
        | sort_by(.state != "Booted")
        | .[0].udid // empty'
}

# Boots the simulator (no-op if already booted), records its current
# appearance in ORIG_APPEARANCE and installs an EXIT trap that restores it,
# even if the run fails midway.
#
# `simctl ui <udid> appearance` reports a real value only once the device is
# booted — while shut down it prints "unknown" (and still exits 0), so the
# read must come after bootstatus. Anything other than light/dark restores to
# light. The setting itself persists across shutdown/boot. See Issue #217.
boot_and_restore_appearance_on_exit() {
  _APPEARANCE_UDID="$1"
  xcrun simctl boot "$_APPEARANCE_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$_APPEARANCE_UDID" -b >/dev/null

  case "$(xcrun simctl ui "$_APPEARANCE_UDID" appearance 2>/dev/null)" in
    dark) ORIG_APPEARANCE="dark" ;;
    *)    ORIG_APPEARANCE="light" ;;
  esac
  add_exit_handler _restore_appearance
  echo "==> Appearance before run: $ORIG_APPEARANCE (restored on exit)"
}

_restore_appearance() {
  xcrun simctl ui "$_APPEARANCE_UDID" appearance "$ORIG_APPEARANCE" >/dev/null 2>&1 \
    || echo "warn: could not restore simulator appearance to $ORIG_APPEARANCE" >&2
}

# Registers a function to run on EXIT. A plain `trap … EXIT` keeps only the
# last handler, so the appearance and content-size restorers would overwrite
# each other; this runs every registered handler in order.
_EXIT_HANDLERS=()
add_exit_handler() {
  _EXIT_HANDLERS+=("$1")
  trap _run_exit_handlers EXIT
}

_run_exit_handlers() {
  local handler
  for handler in "${_EXIT_HANDLERS[@]}"; do
    "$handler"
  done
}

# Dynamic Type categories `simctl ui <udid> content_size` accepts.
CONTENT_SIZES="extra-small small medium large extra-large extra-extra-large extra-extra-extra-large \
accessibility-medium accessibility-large accessibility-extra-large accessibility-extra-extra-large accessibility-extra-extra-extra-large"

# Returns 0 when $1 is one of CONTENT_SIZES. Validate before setting:
# `simctl ui <udid> content_size <bogus>` prints "Invalid argument" but still
# exits 0 and leaves the size unchanged (measured 2026-10-11, Issue #248).
is_valid_content_size() {
  [[ " $CONTENT_SIZES " == *" $1 "* ]]
}

# Sets the simulator's Dynamic Type size and restores the previous one on exit,
# even if the run fails midway (the setting persists on the device otherwise).
# Call after boot_and_restore_appearance_on_exit: like appearance, the read
# returns "unknown" (exit 0) while the device is shut down, so it needs a booted
# device. Anything other than a known size restores to "large" (the default).
# Fails if the read-back does not match, because `simctl` does not.
set_content_size_and_restore_on_exit() {
  _CONTENT_SIZE_UDID="$1"
  local size="$2" current
  ORIG_CONTENT_SIZE="$(xcrun simctl ui "$_CONTENT_SIZE_UDID" content_size 2>/dev/null)"
  is_valid_content_size "$ORIG_CONTENT_SIZE" || ORIG_CONTENT_SIZE="large"
  add_exit_handler _restore_content_size
  xcrun simctl ui "$_CONTENT_SIZE_UDID" content_size "$size" >/dev/null 2>&1 || true
  current="$(xcrun simctl ui "$_CONTENT_SIZE_UDID" content_size 2>/dev/null)"
  if [[ "$current" != "$size" ]]; then
    echo "error: could not set content size to $size (simulator reports: $current)" >&2
    return 1
  fi
  echo "==> Content size: $ORIG_CONTENT_SIZE → $size (restored on exit)"
}

_restore_content_size() {
  xcrun simctl ui "$_CONTENT_SIZE_UDID" content_size "$ORIG_CONTENT_SIZE" >/dev/null 2>&1 \
    || echo "warn: could not restore simulator content size to $ORIG_CONTENT_SIZE" >&2
}
