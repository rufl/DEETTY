#!/usr/bin/env sh
set -eu
export LC_ALL=C

run_smoke() {
  attempts=1
  case "$1" in
    ./scripts/native_grid_smoke.sh|./scripts/native_grid_modes_smoke.sh|./scripts/native_grid_layout_tui_matrix.sh|./scripts/native_grid_tab_reorder_smoke.sh|./scripts/native_grid_tab_navigation_smoke.sh|./scripts/native_grid_resize_overlay_smoke.sh|./scripts/native_grid_shortcut_live_smoke.sh)
      attempts=2
      ;;
  esac
  attempt=1
  while ! sh "$1"; do
    test "$attempt" -lt "$attempts" || return 1
    attempt=$((attempt + 1))
    printf 'native_release_smoke retry=%s attempt=%s/%s\n' "$1" "$attempt" "$attempts" >&2
    sleep 0.2
  done
  sleep 0.2
}

run_smoke ./scripts/native_grid_smoke.sh
run_smoke ./scripts/native_grid_modes_smoke.sh
run_smoke ./scripts/native_grid_two_pane_smoke.sh
run_smoke ./scripts/native_grid_pane_close_smoke.sh
run_smoke ./scripts/native_grid_terminal_chords_smoke.sh
run_smoke ./scripts/native_grid_layout_preset_smoke.sh
run_smoke ./scripts/native_grid_layout_tui_matrix.sh
run_smoke ./scripts/native_grid_recursive_split_smoke.sh
run_smoke ./scripts/native_grid_eight_pane_smoke.sh
run_smoke ./scripts/native_grid_click_focus_smoke.sh
run_smoke ./scripts/native_grid_two_tab_smoke.sh
run_smoke ./scripts/native_grid_tab_reorder_smoke.sh
run_smoke ./scripts/native_grid_tab_rename_smoke.sh
run_smoke ./scripts/native_grid_tab_color_smoke.sh
run_smoke ./scripts/native_grid_profile_preset_smoke.sh
run_smoke ./scripts/native_grid_tab_navigation_smoke.sh
run_smoke ./scripts/native_grid_resize_overlay_smoke.sh
run_smoke ./scripts/native_grid_window_tray_smoke.sh
run_smoke ./scripts/native_grid_clipboard_smoke.sh
run_smoke ./scripts/native_grid_notification_smoke.sh
run_smoke ./scripts/native_grid_settings_smoke.sh
run_smoke ./scripts/native_grid_credentialed_ssh_smoke.sh
run_smoke ./scripts/native_grid_settings_stacking_smoke.sh
run_smoke ./scripts/native_grid_theme_smoke.sh
run_smoke ./scripts/native_grid_project_editor_smoke.sh
run_smoke ./scripts/native_grid_workspace_activation_smoke.sh
run_smoke ./scripts/native_grid_maintenance_smoke.sh
run_smoke ./scripts/native_grid_hot_session_smoke.sh
run_smoke ./scripts/native_grid_workspace_smoke.sh
run_smoke ./scripts/native_grid_pane_move_smoke.sh
run_smoke ./scripts/native_grid_compact_ux_smoke.sh
run_smoke ./scripts/native_grid_note_overlay_smoke.sh
run_smoke ./scripts/native_grid_shortcut_live_smoke.sh
if ./zig-out/bin/noctty --status 2>/dev/null | grep -F 'running=true' >/dev/null; then
  dbus-run-session -- sh ./scripts/native_grid_noctalia_ipc_smoke.sh
else
  sh ./scripts/native_grid_noctalia_ipc_smoke.sh
fi
sleep 0.2
run_smoke ./scripts/native_grid_hidpi_theme_smoke.sh
run_smoke ./scripts/nocted_native_matrix.sh
echo "native_release_smoke renderer=true modes=true tabs=true tab_add=true tab_reorder=true tab_reorder_pointer_drag=true late_callback_guard=true popup_teardown=true window_controls=true tab_rename=true tab_color=true profile_presets=true navigation=true alt_scroll=true ctrl_alt_scroll=true tab_close=true pane_close=true terminal_chords=true layout_presets=true layout_tui=true resize_overlay=true window_resize=true tray=true splits=true recursive_splits=true eight_panes=true click_focus=true clean_selection=true pane_move=true live_tab_position=true compact_ux=true note_overlay=true hot_session=true clipboard=true notifications=true settings=true credentialed_ssh=true settings_stacking=true themes=true project=true workspace_activation=true recent_workspaces=true nocted_handoff=true nocted=true maintenance=true workspace=true shortcut=true noctalia_ipc=true hidpi=true"
