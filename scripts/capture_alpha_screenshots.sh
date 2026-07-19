#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

out_dir=${NOCTTY_SCREENSHOT_DIR:-docs/assets}
mkdir -p "$out_dir"

noctty_out="$out_dir/noctty-alpha.png"
nocted_out="$out_dir/nocted-alpha.png"
wait_ms=${NOCTTY_SCREENSHOT_DELAY_MS:-3500}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-alpha-screenshots.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

capture() {
  local output=$1
  if command -v spectacle >/dev/null 2>&1; then
    spectacle --background --nonotify --current --output "$output" --delay "$wait_ms"
  elif command -v grim >/dev/null 2>&1; then
    sleep "$(awk "BEGIN { print $wait_ms / 1000 }")"
    grim "$output"
  elif command -v gnome-screenshot >/dev/null 2>&1; then
    sleep "$(awk "BEGIN { print $wait_ms / 1000 }")"
    gnome-screenshot -f "$output"
  elif command -v import >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    sleep "$(awk "BEGIN { print $wait_ms / 1000 }")"
    import -window root "$output"
  else
    echo "No supported screenshot tool found: install spectacle, grim, gnome-screenshot, or ImageMagick import." >&2
    return 1
  fi
}

focus_window() {
  local title=$1
  if command -v xdotool >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    timeout 3s xdotool search --limit 1 --name "$title" windowactivate >/dev/null 2>&1 || true
  fi
}

launch_and_capture() {
  local label=$1
  local output=$2
  local title=$3
  shift 3

  mkdir -p "$scratch/home-$label" "$scratch/config-$label" "$scratch/cache-$label" "$scratch/data-$label"
  echo "Launching $label..."
  setsid env \
    GTK_MODULES= \
    NO_AT_BRIDGE=1 \
    HOME="$scratch/home-$label" \
    XDG_CONFIG_HOME="$scratch/config-$label" \
    XDG_CACHE_HOME="$scratch/cache-$label" \
    XDG_DATA_HOME="$scratch/data-$label" \
    "$@" >/tmp/noctty-${label}.screenshot.log 2>&1 &
  local pid=$!

  # Give the process a chance to map a window before starting screenshot delay.
  sleep 2
  focus_window "$title"
  echo "Capturing $output..."
  capture "$output"

  echo "Stopping $label..."
  kill -TERM "-$pid" >/dev/null 2>&1 || kill -TERM "$pid" >/dev/null 2>&1 || true
  sleep 1
  kill -KILL "-$pid" >/dev/null 2>&1 || kill -KILL "$pid" >/dev/null 2>&1 || true

  test -s "$output"
}

zig build >/tmp/noctty-alpha-screenshot-build.log 2>&1

launch_and_capture noctty "$noctty_out" "NOCTTY native grid" \
  zig build run -- --native-grid-windowed

launch_and_capture nocted "$nocted_out" "NOCTED" \
  zig build run-nocted -- --project "$repo_root" --open "$repo_root/README.md"

printf 'alpha_screenshots noctty=%s nocted=%s captured=true\n' "$noctty_out" "$nocted_out"
