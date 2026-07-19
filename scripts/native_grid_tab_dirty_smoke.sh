#!/usr/bin/env sh
set -eu

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-dirty-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_tab_dirty_smoke attention=true attention_cleared=true dirty=true saved=true dirty_cleared=true title_preserved=true exited=true$'
