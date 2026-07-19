#!/usr/bin/env sh
set -eu

output=$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-theme-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_theme_smoke rendered=true imported=true format=ghostty selected=true library_persisted=true config_persisted=true reloaded=true exited=true$'
