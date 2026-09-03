#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

if output="$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-recursive-split-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_recursive_split_smoke panes=4 sessions=4 split_down=vertical split_left=horizontal recursive=true dynamic_sessions=true nested_zoom=true full_page=true restored=true exited=true$'
