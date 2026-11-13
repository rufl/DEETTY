#!/usr/bin/env sh
set -eu

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-two-tab-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_two_tab_smoke initial_tabs=1 tab_bar=true compact_tabs=true add_button=true add_position=start add_icon=true add_accessible=true add_clicked=true tabs_created=2 dynamic_tab=true tab_context_menu=true targeted_background=true close_tab=true model_closed=true rendered_closed=true primary_pty_closed=true late_callback_guard=true remaining_tabs=1 tab_bar_after_close=true add_after_close=true add_reopen_after_close=true fresh_context=true remaining_focused=true secondary_grid=true secondary_lifecycle=true exited=true$'
