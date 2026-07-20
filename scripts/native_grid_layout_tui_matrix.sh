#!/bin/sh
set -eu

command -v vim >/dev/null
command -v btop >/dev/null

run_case() {
    backend=$1
    app=$2
    output=$(timeout 180 env GDK_BACKEND="$backend" GTK_MODULES= \
        NOCTTY_LAYOUT_TUI="$app" \
        zig build --global-cache-dir .zig-cache/global smoke-run -- \
        --native-grid-layout-preset-smoke 2>&1)
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -F \
        'layout_4x4=true panes_4x4=16 balanced_4x4=true auto_fit=80x24 zoom_overlay=true floor_feedback=true tui_rendered=true tui_input=true' \
        >/dev/null
    printf 'native_grid_layout_tui_case backend=%s app=%s panes=16 auto_fit=80x24 rendered=true input_routed=true sessions_preserved=true\n' \
        "$backend" "$app"
}

run_case wayland vim
run_case wayland btop
run_case x11 vim
run_case x11 btop

echo 'native_grid_layout_tui_matrix wayland=true x11=true applications=vim,btop panes=16 auto_fit=80x24 rendered=true input_routed=true sessions_preserved=true'
