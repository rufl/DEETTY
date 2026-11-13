#!/bin/sh
set -eu

case "${1:-any}" in
  any) ;;
  --dedicated)
    if [ "${DEETTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
      echo 'require_isolated_display error=dedicated_session_required' >&2
      exit 2
    fi
    ;;
  *)
    echo 'require_isolated_display error=invalid_mode' >&2
    exit 2
    ;;
esac

case "${DEETTY_ISOLATED_DISPLAY:-}" in
  x11)
    if [ -z "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
      echo 'require_isolated_display error=invalid_x11_boundary' >&2
      exit 2
    fi
    ;;
  wayland)
    if [ -n "${DISPLAY:-}" ] || [ -z "${WAYLAND_DISPLAY:-}" ] ||
      [ ! -S "${XDG_RUNTIME_DIR:-}/$WAYLAND_DISPLAY" ]; then
      echo 'require_isolated_display error=invalid_wayland_boundary' >&2
      exit 2
    fi
    ;;
  '')
    if [ "${DEETTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
      echo 'require_isolated_display error=dedicated_session_required' >&2
      exit 2
    fi
    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
      echo 'require_isolated_display error=display_missing' >&2
      exit 2
    fi
    ;;
  *)
    echo 'require_isolated_display error=unknown_boundary' >&2
    exit 2
    ;;
esac
