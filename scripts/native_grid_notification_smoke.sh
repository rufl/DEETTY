#!/usr/bin/env sh
set -eu

if [ "${DEETTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DEETTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DEETTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

expected='native_grid_notification_smoke tooltip=true status_border=true dbus=true delivered=true exited=true'
attempt=1
max_attempts=3
while [ "$attempt" -le "$max_attempts" ]; do
    output=$(ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-notification-smoke 2>&1 || true)
    printf '%s\n' "$output"
    if printf '%s\n' "$output" | grep -q "^${expected}$"; then
        exit 0
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -le "$max_attempts" ]; then
        sleep 0.25
    fi
done
exit 1
