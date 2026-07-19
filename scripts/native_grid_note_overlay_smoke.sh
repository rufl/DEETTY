#!/usr/bin/env sh
set -eu

receipt='native_grid_note_overlay_smoke alt_hold=true visible_panes=2 workspace_note=true utf8=true multiline=true compact=true hidden_on_release=true exited=true'

wayland_output=$(GDK_BACKEND=wayland zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-note-overlay-smoke)
printf '%s\n' "$wayland_output"
printf '%s\n' "$wayland_output" | grep -q "^${receipt}$"

x11_output=$(GDK_BACKEND=x11 zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-note-overlay-smoke)
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -q "^${receipt}$"

printf '%s\n' 'native_grid_note_overlay_matrix wayland=true x11=true alt_hold=true visible_panes=2 compact=true hidden_on_release=true'
