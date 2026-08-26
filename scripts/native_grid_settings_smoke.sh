#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-settings-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_settings_smoke rendered=true toolbar=true settings_button=true close_button=true order=yakuake button_pointer=true button_tooltips=true settings_activated=true close_activated=true session_stopped=true geometry=sane dialogs=above_terminal application_icon=true categories=3 category_navigation=true category_tooltips=true narrow_access=true page_switch=true mode=windowed tabs=bottom live_tab_position=bottom startup_tab_position=bottom dropdown=90x40 animation=120 hide_on_focus_loss=true focus_follows_pointer=true pane_info=true pane_info_toggle=true scrollback=256 scrollback_live=true launch_profile=true launch_feedback=true launch_kind=command launch_shell=/bin/sh launch_cwd=/tmp launch_env=2 launch_scrollback=2048 launch_atomic=true launch_persisted=true launch_runtime=true launch_library=true launch_profiles=1 launch_named=true launch_saved=true launch_selected=true launch_deleted=true launch_continuity_controls=true launch_tmux=true launch_zellij=true shortcut_recorder=true shortcut=F11 shortcut_label=current_updated settings_handoff=true font_family=Monospace font_size=16 smoothing=grayscale hinting=full theme=noctty-high-contrast status=background padding=8 spacing=4 notifications=false preset=readable persisted=true reloaded=true exited=true$'
