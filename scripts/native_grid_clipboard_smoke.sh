#!/usr/bin/env sh
set -eu

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh
export LC_ALL=C

for backend in wayland x11; do
    output=$(timeout 30 env GTK_MODULES= NO_AT_BRIDGE=1 GDK_BACKEND="$backend" \
        ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- \
        --native-grid-clipboard-smoke)
    printf '%s\n' "$output"
    printf '%s\n' "$output" | grep -q '^native_grid_clipboard_smoke clipboard=true paste_safety=true terminal_delivery=true rendered=true exited=true$'
done
echo "native_grid_clipboard_matrix wayland=true x11=true"
