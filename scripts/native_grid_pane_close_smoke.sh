#!/usr/bin/env sh
set -eu
export LC_ALL=C

output=$(GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-pane-close-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_pane_close_smoke initial_panes=2 context_menu=true menu_survived=true menu_popdown=true targeted_primary=true close_terminal=true foreground_guard=true close_confirmed=true model_closed=true rendered_closed=true primary_pty_closed=true session_storage_released=true pty_event_source=true split_collapsed=true remaining_panes=1 remaining_focused=true last_terminal_protected=true secondary_lifecycle=true exited=true$'
