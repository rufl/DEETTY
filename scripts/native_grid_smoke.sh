#!/bin/sh
set -eu
export LC_ALL=C

# Each backend must own a private display/session namespace. Selecting Wayland
# through GDK inside an X11-only wrapper can print an X11 pass before failing,
# which used to make this matrix's receipt misleading.
if [ -z "${DEETTY_ISOLATED_DISPLAY:-}" ]; then
  ./scripts/run_isolated_x11.sh "$0" x11
  ./scripts/run_isolated_wayland.sh "$0" wayland
  echo 'native_grid_renderer_matrix x11=true wayland=true abi=7 dirty_spans=true frame_clock=true glyph_cache=true resize_coalesced=true synchronized_output=true deadman=true warning_fatal=true'
  exit 0
fi

./scripts/require_isolated_display.sh
backend=${1:-${DEETTY_ISOLATED_DISPLAY}}
case "$backend:${DEETTY_ISOLATED_DISPLAY}" in
  x11:x11|wayland:wayland) ;;
  *)
    echo "native_grid_smoke error=backend_isolation_mismatch backend=$backend isolation=${DEETTY_ISOLATED_DISPLAY}" >&2
    exit 2
    ;;
esac

if output="$(env GTK_MODULES= NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings \
  GDK_BACKEND="$backend" ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build \
  smoke-run -- --native-grid-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F \
  'native_grid_smoke gtk=true drawing_surface=true keyboard_abi=true pty=true vt=true exited=true' \
  >/dev/null
printf '%s\n' "$output" | grep -E \
  'native_grid_renderer_smoke abi=7 frame_batches=[1-9][0-9]* damage_rows=[1-9][0-9]* damage_cells=[1-9][0-9]* damage_spans=[1-9][0-9]* damage_source=dirty_spans glyph_batches=[1-9][0-9]* glyph_cells=[1-9][0-9]* glyph_cache_hits=[1-9][0-9]* glyph_fallback_conversions=[0-9]+ grapheme_cells=[1-9][0-9]* rich_style_cells=[1-9][0-9]* frame_presentations=[1-9][0-9]* timeout_presentations=[0-9]+ resize_requests=[1-9][0-9]* resize_commits=[1-9][0-9]* sync_deferrals=[1-9][0-9]* sync_releases=[1-9][0-9]* sync_deadman_releases=[1-9][0-9]* passed=true' \
  >/dev/null
printf 'native_grid_renderer_backend backend=%s isolated=true abi=7 passed=true\n' \
  "$backend"
