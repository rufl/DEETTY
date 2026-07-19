#!/usr/bin/env sh
set -eu

for backend in wayland x11; do
    output=$(GDK_BACKEND="$backend" zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-clipboard-smoke)
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -q '^native_grid_clipboard_smoke clipboard=true paste_safety=true terminal_delivery=true rendered=true exited=true$'
done
echo "native_grid_clipboard_matrix wayland=true x11=true"
