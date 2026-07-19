#!/usr/bin/env sh
set -eu

output=$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-workspace-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_workspace_smoke tab_command=true split_down=true split_left=true broadcast=true selection_indicator=true selected_pane=3 focus_cycle=true pane_move=true rendered_move=true tag=true tag_suggestions=true filter=true filter_indicator=true filter_empty=true filter_empty_context=true filter_empty_clear=true filter_empty_escape=true filter_focus=true filter_cleared=true tabs=2 active_panes=2 visual_ready=true controlled_exit=true exited=true$'
