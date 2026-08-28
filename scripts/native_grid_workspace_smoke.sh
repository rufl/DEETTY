#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh
export LC_ALL=C

output=$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-workspace-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_workspace_smoke tab_command=true split_down=true split_left=true broadcast=true broadcast_shortcut=true broadcast_confirm=true broadcast_cancel_default=true broadcast_disable_immediate=true broadcast_disable_feedback=true broadcast_state_label=true selection_indicator=true selected_pane=3 focus_cycle=true pane_move=true rendered_move=true tag=true tag_suggestions=true filter=true filter_indicator=true filter_empty=true filter_empty_context=true filter_empty_clear=true filter_empty_escape=true filter_focus=true filter_cleared=true tabs=2 active_panes=2 dropdown_minimum=true visual_ready=true controlled_exit=true exited=true$'
