#!/usr/bin/env sh
set -eu

cache_local="${TMPDIR:-/tmp}/noctty-compact-ux-local"
cache_global="${TMPDIR:-/tmp}/noctty-compact-ux-global"
output_file="${TMPDIR:-/tmp}/noctty-compact-ux-output.$$"
rm -rf "$cache_local" "$cache_global"
trap 'rm -rf "$cache_local" "$cache_global"; rm -f "$output_file"' EXIT HUP INT TERM

if GTK_THEME=Adwaita:light zig build smoke-run --cache-dir "$cache_local" --global-cache-dir "$cache_global" -- --native-grid-compact-ux-smoke >"$output_file" 2>&1; then
  :
else
  status=$?
  cat "$output_file" >&2
  exit "$status"
fi
cat "$output_file"
grep -q '^native_grid_compact_ux_smoke palette=true context_palette=true palette_no_tab_rename=true find=true scrollback=true pane_scrollbar=true zoom=true tab_bar_zoom=true direction=true quick_note=true transient_accessible=true terminal_accessible=true dynamic_shortcut=true light_tab_title=true font_wheel=true font_pane=true font_isolated=true plain_scroll=true font_workspace_persisted=true attention=true ime=true terminal_cursor=text dragger=info_bar dragger_cursor=ns-resize side_border=3 diagonal_cursors=false application_icon=true pane_info=true tab_bar_above_info=true pane_source=pty_proc pane_resources=true pane_refresh=coalesced pane_info_dedup=true chrome=transient same_cwd=true saved=true exited=true$' "$output_file"
