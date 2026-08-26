#!/usr/bin/env sh
set -eu

./scripts/require_isolated_display.sh --dedicated

receipt='native_grid_profile_preset_smoke context_menu=true submenu=true menu_survived=true presets=5 exact_target=true current=true readable=true font_size=14 isolated=true high_contrast=true rendered=true mono_no_ligatures=true workspace_dirty=true snapshot=true restored=true exited=true'

wayland_output=$(GDK_BACKEND=wayland zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-profile-preset-smoke)
printf '%s\n' "$wayland_output"
printf '%s\n' "$wayland_output" | grep -q "^${receipt}$"

x11_output=$(GDK_BACKEND=x11 zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-profile-preset-smoke)
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -q "^${receipt}$"

printf '%s\n' 'native_grid_profile_preset_matrix wayland=true x11=true exact_target=true isolated=true persisted=true restored=true'
