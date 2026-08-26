#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

output=$(zig build smoke-run --global-cache-dir .zig-cache/global -- --native-grid-theme-smoke)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q '^native_grid_theme_smoke rendered=true imported=true format=ghostty selected=true library_persisted=true config_persisted=true reloaded=true exited=true$'
