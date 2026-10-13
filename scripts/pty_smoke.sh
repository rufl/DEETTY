#!/usr/bin/env sh
set -eu

cache_dir="${NOCTTY_ZIG_CACHE_DIR:-.zig-cache}"
global_cache_dir="${NOCTTY_ZIG_GLOBAL_CACHE_DIR:-.zig-cache/global}"
prefix="${NOCTTY_INSTALL_PREFIX:-zig-out}"

if output="$(ZIG_GLOBAL_CACHE_DIR="$global_cache_dir" zig build --prefix "$prefix" --cache-dir "$cache_dir" smoke-run -- --pty-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'pty_smoke spawned=true marker=true resized=true exited=true exit_code=0' >/dev/null
echo "pty_smoke zig_owned=true"
