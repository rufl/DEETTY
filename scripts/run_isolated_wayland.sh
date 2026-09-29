#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
  echo 'run_isolated_wayland error=command_required' >&2
  exit 2
fi
for command in dbus-run-session flock kwin_wayland timeout; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "run_isolated_wayland error=missing_tool tool=$command" >&2
    exit 2
  fi
done

case "${NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-300}" in
  ''|*[!0-9]*)
    echo 'run_isolated_wayland error=invalid_timeout' >&2
    exit 2
    ;;
esac
if [ "${NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-300}" -lt 1 ]; then
  echo 'run_isolated_wayland error=invalid_timeout' >&2
  exit 2
fi

timeout_seconds=${NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-300}
lock="${XDG_RUNTIME_DIR:-/tmp}/noctty-isolated-display-$(id -u).lock"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-isolated-wayland.XXXXXX")
cleanup() {
  if ! rm -rf "$scratch" 2>/dev/null; then
    sleep 0.1
    rm -rf "$scratch"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
chmod 0700 "$scratch"
mkdir -p "$scratch/runtime" "$scratch/home" "$scratch/config" \
  "$scratch/state" "$scratch/cache" "$scratch/data"
chmod 0700 "$scratch/runtime"
mkdir -p "$scratch/config/xdg-desktop-portal"
printf '[preferred]\ndefault=gtk;\n' \
  >"$scratch/config/xdg-desktop-portal/portals.conf"

unset DISPLAY WAYLAND_DISPLAY
export NOCTTY_DEDICATED_DISPLAY=1
export NOCTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS="$timeout_seconds"
export NOCTTY_ISOLATED_WAYLAND_ROOT="$scratch"
flock -x -w "$timeout_seconds" "$lock" \
  timeout --kill-after=10 "$timeout_seconds" \
  env HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/config" \
    XDG_STATE_HOME="$scratch/state" XDG_CACHE_HOME="$scratch/cache" \
    XDG_DATA_HOME="$scratch/data" XDG_RUNTIME_DIR="$scratch/runtime" \
    XDG_CURRENT_DESKTOP=noctty-isolated \
    XDG_SESSION_DESKTOP=noctty-isolated KDE_FULL_SESSION= DESKTOP_SESSION= \
  dbus-run-session -- sh -eu -c '
    scratch=$NOCTTY_ISOLATED_WAYLAND_ROOT
    compositor_pid=
    process_live() {
      test -r "/proc/$1/stat" || return 1
      state=$(cut -d " " -f 3 "/proc/$1/stat" 2>/dev/null) || return 1
      test "$state" != Z
    }
    cleanup() {
      if [ -n "$compositor_pid" ] && process_live "$compositor_pid"; then
        kill -TERM "$compositor_pid" 2>/dev/null || true
        attempt=0
        while process_live "$compositor_pid" && [ "$attempt" -lt 50 ]; do
          attempt=$((attempt + 1))
          sleep 0.05
        done
        if process_live "$compositor_pid"; then
          kill -KILL "$compositor_pid" 2>/dev/null || true
        fi
      fi
      if [ -n "$compositor_pid" ]; then
        wait "$compositor_pid" 2>/dev/null || true
      fi
    }
    trap cleanup EXIT
    trap "exit 129" HUP
    trap "exit 130" INT
    trap "exit 143" TERM
    export XDG_RUNTIME_DIR="$scratch/runtime"
    export HOME="$scratch/home"
    export XDG_CONFIG_HOME="$scratch/config"
    export XDG_STATE_HOME="$scratch/state"
    export XDG_CACHE_HOME="$scratch/cache"
    export XDG_DATA_HOME="$scratch/data"
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=noctty-isolated
    export XDG_SESSION_DESKTOP=noctty-isolated
    # Host Qt/GTK theme/plugin variables can load desktop-session modules before
    # the private compositor exists. Clear them so isolation fails or succeeds
    # based only on the reviewed virtual-session environment.
    unset KDE_FULL_SESSION DESKTOP_SESSION QT_QPA_PLATFORM \
      QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE QT_PLUGIN_PATH GTK_PATH \
      GTK_MODULES
    export WAYLAND_DISPLAY=noctty-isolated-wayland
    export GDK_BACKEND=wayland
    export NO_AT_BRIDGE=1
    export NOCTTY_ISOLATED_DISPLAY=wayland
    unset DISPLAY
    mkdir -p "$XDG_RUNTIME_DIR" "$HOME" "$XDG_CONFIG_HOME" \
      "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
    chmod 0700 "$XDG_RUNTIME_DIR"

    kwin_wayland --virtual --no-lockscreen --no-global-shortcuts \
      --no-kactivities --socket "$WAYLAND_DISPLAY" --width 1440 --height 900 \
      >"$scratch/kwin.log" 2>&1 &
    compositor_pid=$!
    attempt=0
    while [ "$attempt" -lt 200 ]; do
      if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then break; fi
      if ! kill -0 "$compositor_pid" 2>/dev/null; then
        cat "$scratch/kwin.log" >&2
        exit 1
      fi
      attempt=$((attempt + 1))
      sleep 0.05
    done
    if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
      cat "$scratch/kwin.log" >&2
      echo "run_isolated_wayland error=compositor_not_ready" >&2
      exit 1
    fi
    "$@"
  ' sh "$@"
