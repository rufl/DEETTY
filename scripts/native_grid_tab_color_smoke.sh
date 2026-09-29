#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(GDK_BACKEND=x11 zig build smoke-run -- --native-grid-tab-color-smoke 2>&1)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_tab_color_smoke menu=true presets=8 default=true applied=blue rendered=true contrast=true shortcut_lighten=true shortcut_darken=true reversible=true workspace_dirty=true snapshot=true exited=true$'
