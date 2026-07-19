#!/usr/bin/env sh
set -eu

wayland_socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY:-wayland-0}"
x11_socket="/tmp/.X11-unix/X${DISPLAY#:}"

if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$wayland_socket" ]; then
  echo "two_pane_preflight wayland_socket=true x11_socket=false"
  exit 0
fi
if [ -n "${DISPLAY:-}" ] && [ -S "$x11_socket" ]; then
  echo "two_pane_preflight wayland_socket=false x11_socket=true"
  exit 0
fi
echo "two_pane_preflight wayland_socket=false x11_socket=false usable_display=false"
exit 1
