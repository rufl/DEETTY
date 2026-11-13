#!/bin/sh
set -eu

if [ "${DEETTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DEETTY_ISOLATED_DISPLAY:-}" != wayland ]; then
  export DEETTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=${DEETTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-180}
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

cache_local="${TMPDIR:-/tmp}/deetty-pane-scrollbar-local"
cache_global="${TMPDIR:-/tmp}/deetty-pane-scrollbar-global"
output_file="${TMPDIR:-/tmp}/deetty-pane-scrollbar-output.$$"
trap 'rm -f "$output_file"' EXIT HUP INT TERM

if ZIG_GLOBAL_CACHE_DIR="$cache_global" zig build --cache-dir "$cache_local" smoke-run -- --native-grid-pane-scrollbar-smoke >"$output_file" 2>&1; then
  :
else
  status=$?
  cat "$output_file" >&2
  exit "$status"
fi
cat "$output_file"
grep -q '^native_grid_pane_scrollbar_smoke visible=true per_pane=true mouse_mode_wheel=true track_click=true thumb_drag=true keyboard=true exited=true$' \
  "$output_file"
