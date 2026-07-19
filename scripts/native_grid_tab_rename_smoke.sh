#!/usr/bin/env sh
set -eu

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-tab-rename-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_tab_rename_smoke double_click=true inline=true popup=false outside_cancel=true enter=true rendered=true model=true snapshot=true tabs=2 focus_restored=true exited=true$'
