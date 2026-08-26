#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-dirty-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_tab_dirty_smoke attention=true attention_cleared=true status_notification=true status_acknowledged=true dirty=true saved=true dirty_cleared=true title_preserved=true exited=true$'
