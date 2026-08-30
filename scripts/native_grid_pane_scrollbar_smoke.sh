#!/bin/sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ]; then
  export NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=${NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-180}
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi

cache_local="${TMPDIR:-/tmp}/noctty-pane-scrollbar-local"
cache_global="${TMPDIR:-/tmp}/noctty-pane-scrollbar-global"
output_file="${TMPDIR:-/tmp}/noctty-pane-scrollbar-output.$$"
trap 'rm -f "$output_file"' EXIT HUP INT TERM

if zig build smoke-run --cache-dir "$cache_local" \
    --global-cache-dir "$cache_global" -- \
    --native-grid-pane-scrollbar-smoke >"$output_file" 2>&1; then
  :
else
  status=$?
  cat "$output_file" >&2
  exit "$status"
fi
cat "$output_file"
grep -q '^native_grid_pane_scrollbar_smoke visible=true per_pane=true mouse_mode_wheel=true track_click=true thumb_drag=true keyboard=true exited=true$' \
  "$output_file"
