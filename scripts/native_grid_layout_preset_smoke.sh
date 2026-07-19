#!/usr/bin/env sh
set -eu

output=$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-layout-preset-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_layout_preset_smoke context_menu=true menu_survived=true layout_2x2=true panes_2x2=4 balanced_2x2=true churn_cycles=8 sessions_created=32 sessions_closed=32 layout_3x3=true panes_3x3=9 live_sessions=9 balanced_3x3=true layout_1x1=true panes_1x1=1 surplus_ptys_closed=true session_storage_released=true remaining_focused=true exited=true$'
