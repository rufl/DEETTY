#!/bin/sh
set -eu

if [ "${NOCTTY_LEGACY_DISPLAY_RUNNER:-0}" = 1 ]; then
  shared_runner=false
  legacy_fallback=true
else
  shared_runner=true
  legacy_fallback=false
fi

x11_output=$(DISPLAY=:active-fixture WAYLAND_DISPLAY=wayland-active-fixture \
  NOCTTY_ACTIVE_HOME_FIXTURE="$HOME" \
  NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=30 \
  ./scripts/run_isolated_x11.sh sh -eu -c '
    ./scripts/require_isolated_display.sh
    [ "$NOCTTY_ISOLATED_DISPLAY" = x11 ]
    [ "$XDG_SESSION_TYPE" = x11 ]
    [ "${DISPLAY:-}" != :active-fixture ]
    [ -z "${WAYLAND_DISPLAY:-}" ]
    [ "$HOME" != "$NOCTTY_ACTIVE_HOME_FIXTURE" ]
    private_root=$(dirname "$HOME")
    [ "$(dirname "$XDG_CONFIG_HOME")" = "$private_root" ]
    [ "$(dirname "$XDG_STATE_HOME")" = "$private_root" ]
    [ "$(dirname "$XDG_CACHE_HOME")" = "$private_root" ]
    [ "$(dirname "$XDG_DATA_HOME")" = "$private_root" ]
    [ "$(dirname "$TMPDIR")" = "$private_root" ]
    printf "isolated_x11=true\n"
  ')
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -Fx 'isolated_x11=true' >/dev/null

wayland_output=$(DISPLAY=:active-fixture WAYLAND_DISPLAY=wayland-active-fixture \
  NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=30 \
  ./scripts/run_isolated_wayland.sh sh -eu -c '
    ./scripts/require_isolated_display.sh
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
if NOCTTY_ISOLATED_DISPLAY_SCREEN=1280x0x24 \
  ./scripts/run_isolated_x11.sh true >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=invalid_screen_accepted' >&2
  exit 1
fi
if NOCTTY_LEGACY_DISPLAY_RUNNER=0 \
  OVERZEER_DISPLAY_RUNNER=/noctty/missing/isolated-runner \
  ./scripts/run_isolated_x11.sh true >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=missing_shared_runner_accepted' >&2
  exit 1
fi
if DISPLAY=:active-fixture WAYLAND_DISPLAY=wayland-active-fixture \
  ./scripts/require_isolated_display.sh >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=active_display_accepted' >&2
  exit 1
fi
if DISPLAY=:dedicated-fixture WAYLAND_DISPLAY= \
  ./scripts/require_isolated_display.sh --dedicated >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=unacknowledged_dedicated_accepted' >&2
  exit 1
fi
DISPLAY=:dedicated-fixture WAYLAND_DISPLAY= NOCTTY_DEDICATED_DISPLAY=1 \
  ./scripts/require_isolated_display.sh --dedicated
if DISPLAY=:fixture WAYLAND_DISPLAY= \
  NOCTTY_ISOLATED_DISPLAY=unknown \
  ./scripts/require_isolated_display.sh >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=unknown_boundary_accepted' >&2
  exit 1
fi

echo "isolated_display_smoke x11=true wayland=true active_display_inherited=false private_home=true private_xdg=true serialized=true timeout_bounded=true dynamic_screen=true shared_runner=$shared_runner legacy_fallback=$legacy_fallback direct_wrappers_fail_closed=true dedicated_ack=true fail_closed=true"
