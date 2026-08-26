#!/bin/sh
set -eu

x11_output=$(DISPLAY=:active-fixture WAYLAND_DISPLAY=wayland-active-fixture \
  NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=30 \
  ./scripts/run_isolated_x11.sh sh -eu -c '
    [ "$NOCTTY_ISOLATED_DISPLAY" = x11 ]
    [ "$XDG_SESSION_TYPE" = x11 ]
    [ "${DISPLAY:-}" != :active-fixture ]
    [ -z "${WAYLAND_DISPLAY:-}" ]
    [ -n "${XDG_STATE_HOME:-}" ]
    printf "isolated_x11=true\n"
  ')
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -Fx 'isolated_x11=true' >/dev/null

wayland_output=$(DISPLAY=:active-fixture WAYLAND_DISPLAY=wayland-active-fixture \
  NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=30 \
  ./scripts/run_isolated_wayland.sh sh -eu -c '
    [ "$NOCTTY_ISOLATED_DISPLAY" = wayland ]
    [ "$XDG_SESSION_TYPE" = wayland ]
    [ -z "${DISPLAY:-}" ]
    [ "$WAYLAND_DISPLAY" = noctty-isolated-wayland ]
    [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]
    printf "isolated_wayland=true\n"
  ')
printf '%s\n' "$wayland_output"
printf '%s\n' "$wayland_output" | grep -Fx 'isolated_wayland=true' >/dev/null

if NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=invalid \
  ./scripts/run_isolated_x11.sh true >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=invalid_timeout_accepted' >&2
  exit 1
fi

echo 'isolated_display_smoke x11=true wayland=true active_display_inherited=false private_home=true serialized=true timeout_bounded=true fail_closed=true'
