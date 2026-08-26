#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
  echo 'run_isolated_x11 error=command_required' >&2
  exit 2
fi
case "${NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-300}" in
  ''|*[!0-9]*)
    echo 'run_isolated_x11 error=invalid_timeout' >&2
    exit 2
    ;;
esac
if [ "${NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-300}" -lt 1 ]; then
  echo 'run_isolated_x11 error=invalid_timeout' >&2
  exit 2
fi

timeout_seconds=${NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-300}
screen=${NOCTTY_ISOLATED_DISPLAY_SCREEN:-1440x900x24}
screen_width=${screen%%x*}
screen_tail=${screen#*x}
screen_height=${screen_tail%%x*}
screen_depth=${screen_tail#*x}
case "$screen_width:$screen_height:$screen_depth" in
  *[!0-9:]*|:*|*::*|*:|'')
    echo 'run_isolated_x11 error=invalid_screen' >&2
    exit 2
    ;;
esac
case "$screen_depth" in
  16|24|32) ;;
  *)
    echo 'run_isolated_x11 error=invalid_screen' >&2
    exit 2
    ;;
esac
if [ "$screen_width" -lt 1 ] || [ "$screen_height" -lt 1 ]; then
  echo 'run_isolated_x11 error=invalid_screen' >&2
  exit 2
fi

shared_runner=${OVERZEER_DISPLAY_RUNNER:-$HOME/.local/bin/overzeer-isolated-display}
if [ "${NOCTTY_LEGACY_DISPLAY_RUNNER:-0}" != 1 ]; then
  if [ ! -x "$shared_runner" ]; then
    echo 'run_isolated_x11 error=shared_isolated_display_runner_missing' >&2
    exit 2
  fi
  exec env TMPDIR=/tmp \
    "$shared_runner" --screen "$screen" --timeout "$timeout_seconds" --wm none -- \
    env NOCTTY_ISOLATED_DISPLAY=x11 NOCTTY_SHARED_ISOLATION=1 \
    sh -eu -c '
      root=$(mktemp -d /tmp/noctty-isolated-home.XXXXXX)
      mkdir -p "$root/home" "$root/config" "$root/state" \
        "$root/cache" "$root/data" "$root/tmp"
      export HOME="$root/home"
      export XDG_CONFIG_HOME="$root/config"
      export XDG_STATE_HOME="$root/state"
      export XDG_CACHE_HOME="$root/cache"
      export XDG_DATA_HOME="$root/data"
      export TMPDIR="$root/tmp"
      exec "$@"
    ' sh "$@"
fi

for command in dbus-run-session flock timeout xvfb-run; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "run_isolated_x11 error=missing_tool tool=$command" >&2
    exit 2
  fi
done

lock="${XDG_RUNTIME_DIR:-/tmp}/noctty-isolated-display-$(id -u).lock"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-isolated-x11.XXXXXX")
cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM
chmod 0700 "$scratch"
mkdir -p "$scratch/home" "$scratch/config" "$scratch/state" \
  "$scratch/cache" "$scratch/data"

unset DISPLAY WAYLAND_DISPLAY
export NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS="$timeout_seconds"
export NOCTTY_ISOLATED_X11_ROOT="$scratch"
flock -x -w "$timeout_seconds" "$lock" \
  timeout --kill-after=10 "$timeout_seconds" \
  env HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/config" \
    XDG_STATE_HOME="$scratch/state" XDG_CACHE_HOME="$scratch/cache" \
    XDG_DATA_HOME="$scratch/data" \
  dbus-run-session -- xvfb-run -a -s "-screen 0 $screen -nolisten tcp" \
  sh -eu -c '
    scratch=$NOCTTY_ISOLATED_X11_ROOT
    export HOME="$scratch/home"
    export XDG_CONFIG_HOME="$scratch/config"
    export XDG_STATE_HOME="$scratch/state"
    export XDG_CACHE_HOME="$scratch/cache"
    export XDG_DATA_HOME="$scratch/data"
    export XDG_SESSION_TYPE=x11
    export GDK_BACKEND=x11
    export NO_AT_BRIDGE=1
    export NOCTTY_ISOLATED_DISPLAY=x11
    unset WAYLAND_DISPLAY
    "$@"
  ' sh "$@"
