#!/usr/bin/env sh
set -eu
export LC_ALL=C

receipt='native_grid_terminal_chords_smoke panes=2 broadcast=true ctrl_c=true interrupt_target=current_pane primary_interrupts=0 secondary_interrupts=1 enter=carriage_return line_feed=false ctrl_d=true exact_pane=true eof_forwarded=false final_pane_protected=true remaining_focused=true exited=true'

wayland_output=$(timeout 30 env GDK_BACKEND=wayland zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-terminal-chords-smoke)
printf '%s\n' "$wayland_output"
printf '%s\n' "$wayland_output" | grep -Fqx "$receipt"

x11_output=$(timeout 30 env GDK_BACKEND=x11 zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-terminal-chords-smoke)
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -Fqx "$receipt"

echo 'native_grid_terminal_chords_matrix wayland=true x11=true broadcast_on=true ctrl_c_current_pane_only=true enter=carriage_return line_feed=false ctrl_d_exact_pane=true eof_forwarded=false final_pane_protected=true'
