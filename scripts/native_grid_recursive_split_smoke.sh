#!/usr/bin/env sh
set -eu

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-recursive-split-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_recursive_split_smoke panes=4 sessions=4 split_down=vertical split_left=horizontal recursive=true dynamic_sessions=true exited=true$'
