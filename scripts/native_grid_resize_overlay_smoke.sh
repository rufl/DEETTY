#!/usr/bin/env sh
set -eu

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-resize-overlay-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_resize_overlay_smoke panes=2 divider=true realtime=true format=columns_x_rows position=center initial_hidden=true visible=true updated=true duration_ms=750 hidden=true exited=true$'
