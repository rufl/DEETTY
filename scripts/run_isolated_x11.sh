#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
  echo 'run_isolated_x11 error=command_required' >&2
  exit 2
fi
for command in dbus-run-session flock timeout xvfb-run; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "run_isolated_x11 error=missing_tool tool=$command" >&2
    exit 2
  fi
done

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
  dbus-run-session -- xvfb-run -a -s '-screen 0 1440x900x24 -nolisten tcp' \
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
