#!/bin/sh
set -eu
cache_dir="${NOCTTY_ZIG_CACHE_DIR:-.zig-cache}"
global_cache_dir="${NOCTTY_ZIG_GLOBAL_CACHE_DIR:-.zig-cache/global}"
prefix="${NOCTTY_INSTALL_PREFIX:-zig-out}"

if output="$(zig build --prefix "$prefix" --cache-dir "$cache_dir" --global-cache-dir "$global_cache_dir" smoke-run -- --vt-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'vt_smoke public_vt=true grid=true title=true paste=true' >/dev/null
printf '%s\n' 'vt_smoke renderer_neutral=true'
