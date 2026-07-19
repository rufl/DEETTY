#!/usr/bin/env sh
set -eu

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-tab-title-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_tab_title_smoke fallback=true overflow=true tooltip_full=true rename_override=true exited=true$'
