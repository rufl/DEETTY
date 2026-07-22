#!/bin/sh
set -eu

command -v vim >/dev/null
command -v btop >/dev/null

run_case() {
    backend=$1
    output=$(timeout 180 env GDK_BACKEND="$backend" GTK_MODULES= \
        NOCTTY_LAYOUT_TUI=btop \
        zig build --global-cache-dir .zig-cache/global smoke-run -- \
        --native-grid-layout-preset-smoke 2>&1)
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -F \
        'layout_4x2=true panes_4x2=8 balanced_4x2=true layout_3x3=true panes_3x3=9 balanced_3x3=true layout_4x4=true panes_4x4=16 balanced_4x4=true auto_fit=80x24 zoom_overlay=true floor_feedback=true tui_rendered=true tui_input=true' \
        >/dev/null
    printf 'native_grid_layout_tui_case backend=%s app=btop panes=16 auto_fit=80x24 rendered=true input_routed=true sessions_preserved=true\n' \
        "$backend"
}

run_case wayland
run_case x11

echo 'native_grid_layout_tui_matrix wayland=true x11=true applications=vim,btop panes=16 auto_fit=80x24 rendered=true input_routed=true sessions_preserved=true'
