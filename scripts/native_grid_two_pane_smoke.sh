#!/usr/bin/env sh
set -eu

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-two-pane-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_two_pane_smoke panes=2 dynamic_split=true primary_pty=true secondary_pty=true pty_event_source=true primary_grid=true secondary_grid=true secondary_lifecycle=true exited=true$'
