#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-maintenance-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_maintenance_smoke timer=true autosave=true project_refresh=true recovery_cleanup=true descriptor_fallback=root_coalesced pane_exit_timer=false source_cleanup=centralized exited=true$'
