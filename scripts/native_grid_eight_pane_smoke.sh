#!/usr/bin/env sh
set -eu

if [ "${DEETTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DEETTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DEETTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

if output="$(ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-eight-pane-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_eight_pane_smoke panes=8 sessions=8 balanced=true split_down=vertical split_left=horizontal dynamic_sessions=true descriptor_fallback=root_coalesced pane_exit_timers=0 periodic_callbacks_per_second=3 exited=true$'
