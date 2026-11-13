#!/usr/bin/env bash
# Repository-owned X11 test boundary for clean CI and contributor checkouts.
set -euo pipefail

readonly program_name='dintty-isolated-display'
readonly io_full_limit="${DINTTY_DISPLAY_IO_FULL_LIMIT:-8}"
readonly blocked_limit="${DINTTY_DISPLAY_BLOCKED_LIMIT:-8}"
readonly lock_wait_seconds="${DINTTY_DISPLAY_LOCK_WAIT_SECONDS:-60}"

timeout_seconds="${DINTTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS:-300}"
screen="${DINTTY_ISOLATED_DISPLAY_SCREEN:-1440x900x24}"
window_manager=none
command_args=()

log() {
  printf '%s: %s\n' "$program_name" "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: scripts/isolated_display_runner.sh [--timeout SECONDS] [--screen WxHxD]
       [--wm COMMAND|auto] -- COMMAND [ARG...]

Runs one graphical command with private mount/PID/IPC/network namespaces,
private /tmp and runtime sockets, a private D-Bus session, and Xvfb. Runs are
serialized, pressure-gated, time-bounded, and terminated as a process group.
EOF
}

io_full_avg10() {
  local value
  [[ -r /proc/pressure/io ]] || return 1
  value=$(awk '/^full / { for (i = 1; i <= NF; i++) if ($i ~ /^avg10=/) { sub(/^avg10=/, "", $i); print $i; exit } }' /proc/pressure/io)
  [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  printf '%s\n' "$value"
}

blocked_tasks() {
  local count=0 process state
  for process in /proc/[0-9]*/stat; do
    state=$(awk '{ print $3 }' "$process" 2>/dev/null || true)
    if [[ "$state" == D ]]; then count=$((count + 1)); fi
  done
  printf '%s\n' "$count"
}

pressure_is_critical() {
  local io_full blocked
  io_full=$(io_full_avg10) || {
    log 'cannot read the host I/O pressure signal'
    return 2
  }
  blocked=$(blocked_tasks)
  if awk -v value="$io_full" -v limit="$io_full_limit" 'BEGIN { exit !(value >= limit) }'; then
    return 0
  fi
  ((blocked >= blocked_limit)) && return 0
  return 1
}

run_inner() {
  local wm=$1
  shift
  [[ "${1:-}" == -- ]] || {
    log 'invalid internal invocation'
    exit 2
  }
  shift

  export LICHFORGE_ISOLATED_DISPLAY=1
  export DINTTY_ISOLATED_WINDOW_MANAGER="$wm"
  export LIBGL_ALWAYS_SOFTWARE=1
  export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
  export XDG_SESSION_TYPE=x11
  export GDK_BACKEND=x11
  export QT_QPA_PLATFORM=xcb
  unset WAYLAND_DISPLAY XAUTHORITY KDE_FULL_SESSION KDE_SESSION_VERSION \
    GNOME_DESKTOP_SESSION_ID QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE \
    QT_PLUGIN_PATH GTK_PATH GTK_MODULES

  local wm_pid=
  local test_status
  cleanup_inner() {
    if [[ -n "$wm_pid" ]]; then
      kill -TERM "$wm_pid" 2>/dev/null || true
      wait "$wm_pid" 2>/dev/null || true
    fi
  }
  trap 'cleanup_inner; exit 129' HUP
  trap 'cleanup_inner; exit 130' INT
  trap 'cleanup_inner; exit 143' TERM

  if [[ "$wm" != none ]]; then
    "$wm" >"${TMPDIR:-/tmp}/isolated-wm.log" 2>&1 &
    wm_pid=$!
    sleep 1
    if ! kill -0 "$wm_pid" 2>/dev/null; then
      cat "${TMPDIR:-/tmp}/isolated-wm.log" >&2 || true
      log "isolated window manager exited during startup: $wm"
      exit 1
    fi
  fi

  set +e
  "$@"
  test_status=$?
  set -e
  cleanup_inner
  trap - HUP INT TERM
  return "$test_status"
}

if [[ "${1:-}" == --inner ]]; then
  shift
  run_inner "$@"
  exit
fi

while (($#)); do
  case "$1" in
    --timeout)
      [[ $# -ge 2 ]] || { log 'missing --timeout value'; exit 2; }
      timeout_seconds=$2
      shift 2
      ;;
    --screen)
      [[ $# -ge 2 ]] || { log 'missing --screen value'; exit 2; }
      screen=$2
      shift 2
      ;;
    --wm)
      [[ $# -ge 2 ]] || { log 'missing --wm value'; exit 2; }
      window_manager=$2
      shift 2
      ;;
    --)
      shift
      command_args=("$@")
      break
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      log "unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

((${#command_args[@]} > 0)) || { log 'missing command'; exit 2; }
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || { log 'timeout must be a positive integer'; exit 2; }
[[ "$screen" =~ ^[1-9][0-9]*x[1-9][0-9]*x(16|24|32)$ ]] || { log 'screen must use WxHx16, WxHx24, or WxHx32'; exit 2; }
[[ "$window_manager" =~ ^[A-Za-z0-9._+-]+$ ]] || { log 'invalid window-manager command'; exit 2; }
[[ "$io_full_limit" =~ ^[0-9]+([.][0-9]+)?$ ]] || { log 'invalid I/O pressure limit'; exit 2; }
[[ "$blocked_limit" =~ ^[0-9]+$ ]] || { log 'invalid blocked-task limit'; exit 2; }
[[ "$lock_wait_seconds" =~ ^[0-9]+$ ]] || { log 'invalid lock wait'; exit 2; }

for dependency in awk bwrap dbus-run-session flock setsid stat timeout xvfb-run; do
  command -v "$dependency" >/dev/null 2>&1 || {
    log "required isolation dependency is missing: $dependency"
    exit 1
  }
done
if [[ "$window_manager" == auto ]]; then
  window_manager=
  for candidate in openbox kwin_x11 xfwm4; do
    if command -v "$candidate" >/dev/null 2>&1; then
      window_manager=$candidate
      break
    fi
  done
  [[ -n "$window_manager" ]] || {
    log 'no supported isolated X11 window manager found (openbox, kwin_x11, or xfwm4)'
    exit 1
  }
fi
if [[ "$window_manager" != none ]]; then
  command -v "$window_manager" >/dev/null 2>&1 || {
    log "configured isolated window manager is missing: $window_manager"
    exit 1
  }
fi

pressure_status=0
pressure_is_critical || pressure_status=$?
case "$pressure_status" in
  0)
    log "deferred: I/O full PSI=$(io_full_avg10)% blocked=$(blocked_tasks)"
    exit 75
    ;;
  1) ;;
  *) exit 1 ;;
esac

lock_root="${XDG_RUNTIME_DIR:-/tmp}/dintty-isolated-display-${UID}"
if ! mkdir -m 0700 "$lock_root" 2>/dev/null; then
  if [[ ! -d "$lock_root" || -L "$lock_root" ]] ||
    [[ $(stat -c %u "$lock_root") != "$UID" ]] ||
    [[ $(stat -c %a "$lock_root") != 700 ]]; then
    log "unsafe display lock directory: $lock_root"
    exit 1
  fi
fi
exec 9>>"$lock_root/runner.lock"
if ! flock -w "$lock_wait_seconds" 9; then
  log "deferred: graphical test lock was busy for ${lock_wait_seconds}s"
  exit 75
fi

pressure_status=0
pressure_is_critical || pressure_status=$?
case "$pressure_status" in
  0)
    log "deferred after lock: I/O full PSI=$(io_full_avg10)% blocked=$(blocked_tasks)"
    exit 75
    ;;
  1) ;;
  *) exit 1 ;;
esac

script_path=$(readlink -f "$0")
private_runtime="/run/user/$UID"
child_pid=
cleanup() {
  if [[ -n "$child_pid" ]]; then
    kill -TERM -- "-$child_pid" 2>/dev/null || true
    sleep 1
    kill -KILL -- "-$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
}
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
trap cleanup EXIT

set +e
setsid timeout --signal=TERM --kill-after=10 "$timeout_seconds" \
  bwrap \
    --die-with-parent \
    --new-session \
    --unshare-pid \
    --unshare-ipc \
    --unshare-uts \
    --unshare-net \
    --bind / / \
    --tmpfs /run/dbus \
    --tmpfs /tmp \
    --tmpfs "$private_runtime" \
    --dir /tmp/dintty-home \
    --dir /tmp/dintty-config \
    --dir /tmp/dintty-state \
    --dir /tmp/dintty-cache \
    --dir /tmp/dintty-data \
    --proc /proc \
    --dev /dev \
    --tmpfs /dev/shm \
    --setenv XDG_RUNTIME_DIR "$private_runtime" \
    --setenv HOME /tmp/dintty-home \
    --setenv XDG_CONFIG_HOME /tmp/dintty-config \
    --setenv XDG_STATE_HOME /tmp/dintty-state \
    --setenv XDG_CACHE_HOME /tmp/dintty-cache \
    --setenv XDG_DATA_HOME /tmp/dintty-data \
    --setenv TMPDIR /tmp \
    --setenv LIBGL_ALWAYS_SOFTWARE 1 \
    --setenv MESA_LOADER_DRIVER_OVERRIDE llvmpipe \
    --setenv __GLX_VENDOR_LIBRARY_NAME mesa \
    --setenv __EGL_VENDOR_LIBRARY_FILENAMES /usr/share/glvnd/egl_vendor.d/50_mesa.json \
    --unsetenv DISPLAY \
    --unsetenv WAYLAND_DISPLAY \
    --unsetenv XAUTHORITY \
    --unsetenv DBUS_SESSION_BUS_ADDRESS \
    --unsetenv DBUS_SYSTEM_BUS_ADDRESS \
    --unsetenv SSH_AUTH_SOCK \
    --unsetenv GPG_AGENT_INFO \
    --unsetenv XDG_ACTIVATION_TOKEN \
    --unsetenv DESKTOP_STARTUP_ID \
    --unsetenv NOTIFY_SOCKET \
    --unsetenv JOURNAL_STREAM \
    --unsetenv SESSION_MANAGER \
    --unsetenv KDE_FULL_SESSION \
    --unsetenv GNOME_DESKTOP_SESSION_ID \
    --unsetenv XDG_CURRENT_DESKTOP \
    --unsetenv DESKTOP_SESSION \
    --unsetenv KDEHOME \
    --unsetenv ICEAUTHORITY \
    --unsetenv PULSE_SERVER \
    dbus-run-session -- sh -eu -c '
      screen=$1
      runner=$2
      wm=$3
      shift 3
      error_log=$XDG_RUNTIME_DIR/xvfb-error.log
      xvfb-run -a -e "$error_log" -s "-screen 0 $screen -nolisten tcp -noreset" \
        "$runner" --inner "$wm" -- "$@"
      status=$?
      if [ "$status" -ne 0 ] && [ -s "$error_log" ]; then
        cat "$error_log" >&2
      fi
      exit "$status"
    ' sh "$screen" "$script_path" "$window_manager" "${command_args[@]}" &
child_pid=$!
wait "$child_pid"
status=$?
child_pid=
set -e
trap - EXIT HUP INT TERM
log "finished exit=$status isolated_display=1"
exit "$status"
