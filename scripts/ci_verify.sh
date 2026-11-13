#!/usr/bin/env sh
set -eu

./scripts/verify.sh

wayland_ready=false
x11_ready=false
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}" ]; then
  wayland_ready=true
fi
if [ -n "${DISPLAY:-}" ]; then
  x11_socket="/tmp/.X11-unix/X${DISPLAY#:}"
  if [ -S "$x11_socket" ]; then x11_ready=true; fi
fi

if [ "$wayland_ready" = true ] || [ "$x11_ready" = true ]; then
  if [ "${DINTTY_RUN_NATIVE_SMOKE:-0}" = "1" ]; then
    if [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
      echo 'ci_verify error=dedicated_native_smoke_session_required' >&2
      exit 2
    fi
    ./scripts/native_host_smoke.sh
    echo "ci_verify display_bound=true run_native_smoke=passed"
  else
    echo "ci_verify display_bound=socket_present run_native_smoke=opt_in DINTTY_RUN_NATIVE_SMOKE=1 DINTTY_DEDICATED_DISPLAY=1"
  fi
else
  echo "ci_verify display_bound=false run_native_smoke=skipped"
fi
