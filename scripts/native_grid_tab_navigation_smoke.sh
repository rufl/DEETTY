#!/usr/bin/env sh
set -eu

receipt='native_grid_tab_navigation_smoke pane_ctrl_tab=true alt_scroll=true alt_scroll_up=true alt_scroll_down=true current_tab=true visible_panes_only=true hidden_skipped=true visual_feedback=true ctrl_alt_scroll=true tab_scroll_up=true tab_scroll_down=true tab_wraparound=true tab_visual_feedback=true tab_ctrl_shift_tab=true smart_filter_preserved=true cycle_next=true cycle_previous=true shortcut_close=true shortcut_reopen=true focus_restored=true tabs=2 exited=true'

wayland_output=$(GDK_BACKEND=wayland zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-tab-navigation-smoke)
printf '%s\n' "$wayland_output"
printf '%s\n' "$wayland_output" | grep -Fqx "$receipt"

x11_output=$(GDK_BACKEND=x11 zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-tab-navigation-smoke)
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -Fqx "$receipt"

echo 'native_grid_tab_navigation_matrix wayland=true x11=true alt_scroll=true ctrl_alt_scroll=true current_tab=true hidden_skipped=true pane_visual_feedback=true tab_wraparound=true tab_visual_feedback=true'
