#!/usr/bin/env sh
set -eu
export LC_ALL=C

receipt='native_grid_hot_session_smoke autosave=true atomic=true write_through=true startup_restore=true tabs=2 panes=5 recursive_layout=true ratios=true titles=true colors=true tags=true smart_filter=true profiles=true settings=true cwd=true corrupt_fallback=true processes=restarted exited=true'

wayland_output=$(GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings GDK_BACKEND=wayland zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-hot-session-smoke)
printf '%s\n' "$wayland_output"
printf '%s\n' "$wayland_output" | grep -q "^${receipt}$"

x11_output=$(GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings GDK_BACKEND=x11 zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-hot-session-smoke)
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -q "^${receipt}$"

printf '%s\n' 'native_grid_hot_session_matrix wayland=true x11=true atomic=true tabs=2 panes=5 ratios=true corrupt_fallback=true warning_fatal=true popup_teardown=true'
