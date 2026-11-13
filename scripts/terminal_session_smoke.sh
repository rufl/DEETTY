#!/bin/sh
set -eu
cache_dir="${DINTTY_ZIG_CACHE_DIR:-.zig-cache}"
global_cache_dir="${DINTTY_ZIG_GLOBAL_CACHE_DIR:-.zig-cache/global}"
prefix="${DINTTY_INSTALL_PREFIX:-zig-out}"

if output="$(ZIG_GLOBAL_CACHE_DIR="$global_cache_dir" zig build --prefix "$prefix" --cache-dir "$cache_dir" smoke-run -- --terminal-session-smoke 2>&1)"; then
  :
else
  status=$?
  printf '%s\n' "$output" >&2
  exit "$status"
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'terminal_session_smoke pty=true vt=true grid=true title=true exited=true' >/dev/null
printf '%s\n' 'terminal_session_smoke renderer_input_ready=true'
