#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_wayland.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(timeout 90 env GDK_BACKEND=wayland GTK_MODULES= NO_AT_BRIDGE=1 \
    zig build smoke-run --global-cache-dir .zig-cache/global -- \
    --native-grid-4x4-smoke 2>&1)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -qx \
    'native_grid_4x4_smoke route=workspace_menu production_tab=true panes=16 balanced=true mapped=true pty_ready=true all_panes_drawn=true all_panes_nonblank=true tui_rendered=true tui_input=true sessions_created=16 source_tab_preserved=true restored=true exited=true'
