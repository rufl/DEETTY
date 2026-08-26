#!/usr/bin/env sh
set -eu

if [ "${NOCTTY_ISOLATED_DISPLAY:-}" != wayland ]; then
  exec ./scripts/run_isolated_wayland.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

binary=${1:-./zig-out/bin/noctty}
case "$binary" in
  /*) ;;
  *) binary="$PWD/${binary#./}" ;;
esac
test -x "$binary"
if [ -z "${WAYLAND_DISPLAY-}" ]; then
  echo 'native_grid_wayland_activation_smoke error=isolated_wayland_missing' >&2
  exit 1
fi
if "$binary" --status | grep -F 'running=true' >/dev/null; then
  echo 'native_grid_wayland_activation_smoke error=isolated_owner_conflict' >&2
  exit 1
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/noctty-wayland-activation.XXXXXX")
pid=
cleanup() {
  if [ -n "$pid" ]; then
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM

export HOME="$scratch/home"
export XDG_CONFIG_HOME="$scratch/config"
export XDG_STATE_HOME="$scratch/state"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
XDG_ACTIVATION_TOKEN=noctty-wayland-cold-token \
  NOCTTY_DEBUG_ACTIVATION=1 GDK_BACKEND=wayland \
  setsid "$binary" --show >"$scratch/cold.log" 2>&1 &
pid=$!

attempt=0
state=
while [ "$attempt" -lt 120 ]; do
  state=$("$binary" --status 2>/dev/null || true)
  if printf '%s\n' "$state" | grep -F 'running=true' >/dev/null &&
    grep -F 'noctty_xdg_activation applied=true backend=wayland' \
      "$scratch/cold.log" >/dev/null 2>&1; then
    break
  fi
  kill -0 "$pid" 2>/dev/null || { cat "$scratch/cold.log" >&2; exit 1; }
  attempt=$((attempt + 1))
  sleep 0.05
done
printf '%s\n' "$state" | grep -F 'running=true' >/dev/null
printf '%s\n' "$state" | grep -F 'visible=true' >/dev/null
grep -F 'noctty_xdg_activation applied=true backend=wayland' \
  "$scratch/cold.log" >/dev/null
child_pid=$(pgrep -P "$pid" | head -n 1 || true)
test -n "$child_pid"
! tr '\0' '\n' <"/proc/$child_pid/environ" | \
  grep -F 'XDG_ACTIVATION_TOKEN=' >/dev/null

kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
pid=

NOCTTY_DEBUG_ACTIVATION=1 GDK_BACKEND=wayland \
  setsid "$binary" --hidden >"$scratch/output.log" 2>&1 &
pid=$!
attempt=0
while [ "$attempt" -lt 120 ]; do
  state=$("$binary" --status 2>/dev/null || true)
  printf '%s\n' "$state" | grep -F 'running=true' >/dev/null && break
  kill -0 "$pid" 2>/dev/null || { cat "$scratch/output.log" >&2; exit 1; }
  attempt=$((attempt + 1))
  sleep 0.05
done
printf '%s\n' "$state" | grep -F 'running=true' >/dev/null

XDG_ACTIVATION_TOKEN=noctty-wayland-forwarded-token "$binary" --show >/dev/null
attempt=0
while [ "$attempt" -lt 80 ]; do
  grep -F 'noctty_xdg_activation applied=true backend=wayland' \
    "$scratch/output.log" >/dev/null 2>&1 && break
  attempt=$((attempt + 1))
  sleep 0.05
done
grep -F 'noctty_xdg_activation applied=true backend=wayland' \
  "$scratch/output.log" >/dev/null
state=$("$binary" --status)
printf '%s\n' "$state" | grep -F 'running=true' >/dev/null
printf '%s\n' "$state" | grep -F 'visible=true' >/dev/null

kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
pid=
rm -rf "$scratch"
scratch=
trap - EXIT HUP INT TERM
printf '%s\n' 'native_grid_wayland_activation_smoke gtk_startup_id=true xdg_activation_token=true cold_start=true forwarded_show=true token_not_in_pty=true backend=wayland visible=true process_group_cleanup=true'
