#!/usr/bin/env sh
set -eu

if output="$(GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
  zig build smoke-run --global-cache-dir .zig-cache/global -- \
  --native-grid-click-focus-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_click_focus_smoke panes=2 primary_click=true secondary_click=true clean_click=true hover_trails=false double_click_zoom=true zoom_selection=false restore_selection=false drag_selection=true focus_switched=true primary_input=true secondary_input=true focus_readiness=bounded controlled_exit=true exited=true$'
