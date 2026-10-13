#!/usr/bin/env sh
set -eu

./scripts/require_isolated_display.sh --dedicated

receipt='native_grid_settings_stacking_smoke visible=true transient_parent=true keep_above=true compositor_stack=true geometry=sane parent_restored=true exited=true'

wayland_output=$(GDK_BACKEND=wayland ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-settings-stacking-smoke)
printf '%s\n' "$wayland_output"
printf '%s\n' "$wayland_output" | grep -q "^${receipt}$"

x11_output=$(GDK_BACKEND=x11 ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- --native-grid-settings-stacking-smoke)
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -q "^${receipt}$"

printf '%s\n' 'native_grid_settings_stacking_matrix wayland=true x11=true transient_parent=true keep_above=true compositor_stack=true parent_restored=true'
