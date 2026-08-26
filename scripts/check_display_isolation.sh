#!/bin/sh
set -eu

for helper in scripts/require_isolated_display.sh \
  scripts/run_isolated_x11.sh scripts/run_isolated_wayland.sh; do
  test -x "$helper"
done

self_isolated='
scripts/native_grid_4x4_smoke.sh
scripts/native_grid_click_focus_smoke.sh
scripts/native_grid_clipboard_smoke.sh
scripts/native_grid_compact_ux_smoke.sh
scripts/native_grid_credentialed_ssh_smoke.sh
scripts/native_grid_eight_pane_smoke.sh
scripts/native_grid_hidpi_theme_smoke.sh
scripts/native_grid_layout_preset_smoke.sh
scripts/native_grid_layout_tui_matrix.sh
scripts/native_grid_maintenance_smoke.sh
scripts/native_grid_modes_smoke.sh
scripts/native_grid_noctalia_ipc_smoke.sh
scripts/native_grid_notification_smoke.sh
scripts/native_grid_palette_rename_smoke.sh
scripts/native_grid_pane_close_smoke.sh
scripts/native_grid_pane_move_smoke.sh
scripts/native_grid_project_editor_smoke.sh
scripts/native_grid_recursive_split_smoke.sh
scripts/native_grid_resize_overlay_smoke.sh
scripts/native_grid_resource_qualification.sh
scripts/native_grid_settings_smoke.sh
scripts/native_grid_smoke.sh
scripts/native_grid_tab_color_smoke.sh
scripts/native_grid_tab_dirty_smoke.sh
scripts/native_grid_tab_rename_smoke.sh
scripts/native_grid_tab_title_smoke.sh
scripts/native_grid_theme_smoke.sh
scripts/native_grid_two_pane_smoke.sh
scripts/native_grid_two_tab_smoke.sh
scripts/native_grid_wayland_activation_smoke.sh
scripts/native_grid_window_tray_smoke.sh
scripts/native_grid_workspace_activation_smoke.sh
scripts/native_grid_workspace_smoke.sh
scripts/nocted_native_smoke.sh
scripts/nocted_resource_qualification.sh
'

dedicated='
scripts/capture_alpha_screenshots.sh
scripts/local_interaction_spike_report.sh
scripts/native_grid_authenticated_agent_qualification.sh
scripts/native_grid_full_stack_qualification.sh
scripts/native_grid_hot_session_smoke.sh
scripts/native_grid_installed_continuity_qualification.sh
scripts/native_grid_note_overlay_smoke.sh
scripts/native_grid_presentation_qualification.sh
scripts/native_grid_profile_preset_smoke.sh
scripts/native_grid_settings_stacking_smoke.sh
scripts/native_grid_shortcut_live_smoke.sh
scripts/native_grid_stability_qualification.sh
scripts/native_grid_tab_navigation_smoke.sh
scripts/native_grid_tab_reorder_smoke.sh
scripts/native_grid_terminal_chords_smoke.sh
scripts/native_host_smoke.sh
scripts/native_release_smoke.sh
scripts/nocted_native_endurance_qualification.sh
scripts/nocted_native_matrix.sh
scripts/plasma_wayland_post_upgrade.sh
'

guarded=''

self_count=0
for script in $self_isolated; do
  test -s "$script"
  grep -F 'run_isolated_' "$script" >/dev/null
  grep -F 'require_isolated_display.sh' "$script" >/dev/null
  self_count=$((self_count + 1))
done

dedicated_count=0
for script in $dedicated; do
  test -s "$script"
  grep -F 'require_isolated_display.sh --dedicated' "$script" >/dev/null
  dedicated_count=$((dedicated_count + 1))
done

guarded_count=0
for script in $guarded; do
  test -s "$script"
  grep -F 'require_isolated_display.sh' "$script" >/dev/null
  guarded_count=$((guarded_count + 1))
done

grep -F 'if [[ $mode == full ]]' \
  scripts/native_grid_installed_activation_smoke.sh >/dev/null
grep -F 'require_isolated_display.sh --dedicated' \
  scripts/native_grid_installed_activation_smoke.sh >/dev/null
grep -F 'NOCTTY_DEDICATED_DISPLAY' scripts/ci_verify.sh >/dev/null
grep -F 'dedicated_native_smoke_session_required' scripts/ci_verify.sh >/dev/null

printf '%s\n' \
  "display_isolation self_isolated=$self_count dedicated=$dedicated_count guarded=$guarded_count installed_contract_headless=true ci_native_opt_in=true active_display_default=false fail_closed=true"
