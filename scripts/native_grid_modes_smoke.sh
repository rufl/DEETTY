#!/bin/sh
set -eu

if [ "${DEETTY_ISOLATED_DISPLAY:-}" != x11 ] &&
  [ "${DEETTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DEETTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_x11.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

if [ -z "${DISPLAY-}" ] && [ -z "${WAYLAND_DISPLAY-}" ]; then
  echo "native_grid_modes_smoke skipped=true reason=display_missing"
  exit 0
fi

for mode in --native-grid-smoke --native-grid-windowed-smoke --native-grid-zen-smoke; do
  if output="$(GTK_MODULES= ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-run -- "$mode" 2>&1)"; then
    :
  else
    status=$?
    printf '%s\n' "$output" >&2
    exit "$status"
  fi
  printf '%s\n' "$output"
  printf '%s\n' "$output" | grep -F 'native_grid_smoke gtk=true drawing_surface=true keyboard_abi=true pty=true vt=true exited=true' >/dev/null
  if [ "$mode" = '--native-grid-smoke' ]; then
    printf '%s\n' "$output" | grep -E 'native_grid_renderer_smoke abi=7 frame_batches=[1-9][0-9]* damage_rows=[1-9][0-9]* damage_cells=[1-9][0-9]* damage_spans=[1-9][0-9]* damage_source=dirty_spans glyph_batches=[1-9][0-9]* glyph_cells=[1-9][0-9]* glyph_cache_hits=[1-9][0-9]* glyph_fallback_conversions=[0-9]+ grapheme_cells=[1-9][0-9]* rich_style_cells=[1-9][0-9]* frame_presentations=[1-9][0-9]* timeout_presentations=[0-9]+ resize_requests=[1-9][0-9]* resize_commits=[1-9][0-9]* sync_deferrals=[1-9][0-9]* sync_releases=[1-9][0-9]* sync_deadman_releases=[1-9][0-9]* passed=true' >/dev/null
  fi
done
echo "native_grid_modes_smoke dropdown=true windowed=true zen=true abi=7 renderer=true"
