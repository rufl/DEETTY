#!/usr/bin/env sh
set -eu

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-pane-move-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_pane_move_smoke menu_action=true live_reparent=true source_tab_closed=true tabs=1 panes=2 focused=true exited=true$'
