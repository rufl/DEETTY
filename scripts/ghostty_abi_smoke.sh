#!/usr/bin/env sh
set -eu

cache_dir="${DEETTY_ZIG_CACHE_DIR:-.zig-cache}"
global_cache_dir="${DEETTY_ZIG_GLOBAL_CACHE_DIR:-.zig-cache/global}"
prefix="${DEETTY_INSTALL_PREFIX:-zig-out}"

if output="$(ZIG_GLOBAL_CACHE_DIR="$global_cache_dir" zig build --prefix "$prefix" --cache-dir "$cache_dir" run -- --ghostty-probe 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'available=false' >/dev/null
printf '%s\n' "$output" | grep -F 'complete=false' >/dev/null
printf '%s\n' "$output" | grep -F 'platform_surface_supported=false' >/dev/null
printf '%s\n' "$output" | grep -F 'safe_gui_abi=false' >/dev/null

public_vt_header=false
public_vt_library=false
public_gui_header=false
private_gui_library=false
if test -f /usr/include/ghostty/vt.h; then public_vt_header=true; fi
if pkg-config --exists libghostty-vt 2>/dev/null; then public_vt_library=true; fi
if test -f /usr/include/ghostty.h || test -f /usr/local/include/ghostty.h; then public_gui_header=true; fi
if test -f /usr/lib/prettymux/libghostty.so; then private_gui_library=true; fi

test "$public_gui_header" = false
test "$private_gui_library" = false || test "$public_gui_header" = false
echo "ghostty_abi_audit public_vt_header=$public_vt_header public_vt_library=$public_vt_library public_gui_header=$public_gui_header private_gui_library=$private_gui_library safe_gui_abi=false"
echo "ghostty_abi_smoke supported_public_gui_abi=false supported_renderer=zig_grid vte_fallback=true"
