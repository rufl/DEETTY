#!/usr/bin/env sh
set -eu

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

cache_local="${TMPDIR:-/tmp}/dintty-compact-ux-local"
cache_global="${TMPDIR:-/tmp}/dintty-compact-ux-global"
output_file="${TMPDIR:-/tmp}/dintty-compact-ux-output.$$"
rm -rf "$cache_local" "$cache_global"
trap 'rm -rf "$cache_local" "$cache_global"; rm -f "$output_file"' EXIT HUP INT TERM

if GTK_THEME=Adwaita:light ZIG_GLOBAL_CACHE_DIR="$cache_global" zig build --cache-dir "$cache_local" smoke-run -- --native-grid-compact-ux-smoke >"$output_file" 2>&1; then
  :
else
  status=$?
  cat "$output_file" >&2
  exit "$status"
fi
cat "$output_file"
grep -q '^native_grid_compact_ux_smoke palette=true context_palette=true context_submenus=true new_1x1_removed=true distribution_cancelled=true palette_no_tab_rename=true find=true scrollback=true pane_scrollbar=true hyperlinks=true hyperlink_context=true hyperlink_tui=true hyperlink_underline=true linear_selection=true linear_selection_copy=true seamless_background=true zoom=true zoom_message=true split_geometry_restored=true tab_bar_zoom=true direction=true quick_note=true transient_accessible=true terminal_accessible=true dynamic_shortcut=true light_tab_title=true font_wheel=true font_pane=true font_isolated=true plain_scroll=true tui_wheel=true tui_caret=true dragger_double_click=true font_workspace_persisted=true attention=true ime=true terminal_cursor=text dragger=2px dragger_cursor=ns-resize side_border=2 diagonal_cursors=false application_icon=true pane_info=true tab_bar_above_info=true pane_source=pty_proc pane_resources=true pane_refresh=coalesced pane_info_dedup=true chrome=transient same_cwd=true saved=true exited=true$' "$output_file"
