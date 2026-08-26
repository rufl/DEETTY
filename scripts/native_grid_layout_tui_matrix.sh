#!/bin/sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

command -v vim >/dev/null
command -v btop >/dev/null

run_case() {
    backend=$1
    application=$2
    output=$(timeout 180 env GDK_BACKEND="$backend" GTK_MODULES= \
        NO_AT_BRIDGE=1 NOCTTY_LAYOUT_TUI="$application" \
        zig build --global-cache-dir .zig-cache/global smoke-run -- \
        --native-grid-4x4-smoke 2>&1)
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -F \
        'native_grid_4x4_smoke route=workspace_menu production_tab=true panes=16 balanced=true mapped=true pty_ready=true all_panes_drawn=true all_panes_nonblank=true tui_rendered=true tui_input=true sessions_created=16 source_tab_preserved=true restored=true exited=true' \
        >/dev/null
    printf 'native_grid_layout_tui_case backend=%s app=%s panes=16 production_4x4=true mapped=true all_panes_drawn=true all_panes_nonblank=true rendered=true input_routed=true source_tab_preserved=true\n' \
        "$backend" "$application"
}

run_case wayland vim
run_case wayland btop
run_case x11 vim
run_case x11 btop

echo 'native_grid_layout_tui_matrix wayland=true x11=true applications=vim,btop panes=16 production_4x4=true mapped=true all_panes_drawn=true all_panes_nonblank=true rendered=true input_routed=true source_tab_preserved=true'
