#!/usr/bin/env sh
set -eu

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-eight-pane-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_eight_pane_smoke panes=8 sessions=8 balanced=true split_down=vertical split_left=horizontal dynamic_sessions=true descriptor_fallback=root_coalesced pane_exit_timers=0 periodic_callbacks_per_second=3 exited=true$'
