#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-layout-preset-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_layout_preset_smoke context_menu=true menu_survived=true layout_2x2=true panes_2x2=4 balanced_2x2=true churn_cycles=8 layout_4x2=true panes_4x2=8 balanced_4x2=true layout_3x3=true panes_3x3=9 balanced_3x3=true layout_4x4=true panes_4x4=16 balanced_4x4=true production_4x4=true all_panes_nonblank=true auto_fit=80x24 zoom_overlay=true floor_feedback=true tui_rendered=true tui_input=true prompt=true cancel_preserved=true accepted=true overflow_tab=true overflow_panes=15 sessions_preserved=16 interactive=true source_focused=true restored=true exited=true$'
