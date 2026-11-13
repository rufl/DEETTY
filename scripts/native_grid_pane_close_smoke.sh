#!/usr/bin/env sh
set -eu

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

export LC_ALL=C
output=$(GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-pane-close-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_pane_close_smoke initial_panes=4 context_menu=true menu_survived=true menu_popdown=true targeted_primary=true close_terminal=true foreground_guard=true close_confirmed=true model_closed=true rendered_closed=true primary_pty_closed=true session_storage_released=true pty_event_source=true split_collapsed=true split_evenly_distributed=true two_by_two=true resize_equal=true evenly_distributed=true user_resize_preserved=true remaining_panes=1 remaining_focused=true last_terminal_protected=true secondary_lifecycle=true exited=true$'
