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
  trap _restore_appearance EXIT
  echo "==> Appearance before run: $ORIG_APPEARANCE (restored on exit)"
}

_restore_appearance() {
  xcrun simctl ui "$_APPEARANCE_UDID" appearance "$ORIG_APPEARANCE" >/dev/null 2>&1 \
    || echo "warn: could not restore simulator appearance to $ORIG_APPEARANCE" >&2
}
