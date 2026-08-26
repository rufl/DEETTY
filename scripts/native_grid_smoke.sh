#!/bin/sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${NOCTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh
export LC_ALL=C

run_backend() {
  backend=$1
  if output="$(env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings GDK_BACKEND="$backend" zig build --global-cache-dir .zig-cache/global smoke-run -- --native-grid-smoke 2>&1)"; then
    :
  else
    status=$?
    printf '%s\n' "$output" >&2
    exit "$status"
  fi
  printf '%s\n' "$output"
  printf '%s\n' "$output" | grep -F 'native_grid_smoke gtk=true drawing_surface=true keyboard_abi=true pty=true vt=true exited=true' >/dev/null
  printf '%s\n' "$output" | grep -E 'native_grid_renderer_smoke abi=2 row_batches=[1-9][0-9]* damage_rows=[1-9][0-9]* damage_cells=[1-9][0-9]* damage_spans=[1-9][0-9]* damage_source=dirty_spans glyph_batches=[1-9][0-9]* glyph_cells=[1-9][0-9]* glyph_cache_hits=[1-9][0-9]* glyph_fallback_conversions=[0-9]+ grapheme_cells=[1-9][0-9]* rich_style_cells=[1-9][0-9]* frame_presentations=[1-9][0-9]* timeout_presentations=[0-9]+ resize_requests=[1-9][0-9]* resize_commits=[1-9][0-9]* sync_deferrals=[1-9][0-9]* sync_releases=[1-9][0-9]* sync_deadman_releases=[1-9][0-9]* passed=true' >/dev/null
}

run_backend x11
run_backend wayland
echo 'native_grid_renderer_matrix x11=true wayland=true abi=2 dirty_spans=true frame_clock=true glyph_cache=true resize_coalesced=true synchronized_output=true deadman=true warning_fatal=true'
