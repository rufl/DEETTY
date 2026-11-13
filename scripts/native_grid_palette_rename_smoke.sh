#!/usr/bin/env sh
set -eu

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

if output="$(ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-palette-rename-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_palette_rename_smoke palette=true validation=true commit=true cancel=true focus_restored=true title_preserved=true exited=true$'
