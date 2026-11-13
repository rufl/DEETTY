#!/bin/sh
set -eu

if [ "${DEETTY_LEGACY_DISPLAY_RUNNER:-0}" = 1 ]; then
  shared_runner=false
  legacy_fallback=true
else
  shared_runner=true
  legacy_fallback=false
fi
active_tmp_marker=$(mktemp /tmp/deetty-active-display.XXXXXX)
cleanup() { rm -f "$active_tmp_marker"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

x11_output=$(DISPLAY=:active-fixture WAYLAND_DISPLAY=wayland-active-fixture \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/active-session-bus \
  DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket \
  SSH_AUTH_SOCK=/run/user/1000/active-agent.sock \
  XDG_ACTIVATION_TOKEN=active-token \
  GDK_BACKEND=wayland DEETTY_ACTIVE_HOME_FIXTURE="$HOME" \
  DEETTY_ACTIVE_TMP_MARKER="$active_tmp_marker" \
  DEETTY_ACTIVE_MOUNT_NS="$(readlink /proc/self/ns/mnt)" \
  DEETTY_ACTIVE_PID_NS="$(readlink /proc/self/ns/pid)" \
  DEETTY_ACTIVE_IPC_NS="$(readlink /proc/self/ns/ipc)" \
  DEETTY_ACTIVE_NET_NS="$(readlink /proc/self/ns/net)" \
  DEETTY_ACTIVE_DBUS_FIXTURE=unix:path=/active-session-bus \
  DEETTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=30 \
  ./scripts/run_isolated_x11.sh sh -eu -c '
    ./scripts/require_isolated_display.sh
    [ "$DEETTY_ISOLATED_DISPLAY" = x11 ]
    [ "$XDG_SESSION_TYPE" = x11 ]
    [ "$GDK_BACKEND" = x11 ]
    [ "${DISPLAY:-}" != :active-fixture ]
    [ -z "${WAYLAND_DISPLAY:-}" ]
    [ "$HOME" != "$DEETTY_ACTIVE_HOME_FIXTURE" ]
    private_root=$(dirname "$HOME")
    [ "$(dirname "$XDG_CONFIG_HOME")" = "$private_root" ]
    [ "$(dirname "$XDG_STATE_HOME")" = "$private_root" ]
    [ "$(dirname "$XDG_CACHE_HOME")" = "$private_root" ]
    [ "$(dirname "$XDG_DATA_HOME")" = "$private_root" ]
    [ "$(dirname "$TMPDIR")" = "$private_root" ]
    [ ! -e "$DEETTY_ACTIVE_TMP_MARKER" ]
    [ "$(readlink /proc/self/ns/mnt)" != "$DEETTY_ACTIVE_MOUNT_NS" ]
    [ "$(readlink /proc/self/ns/pid)" != "$DEETTY_ACTIVE_PID_NS" ]
    [ "$(readlink /proc/self/ns/ipc)" != "$DEETTY_ACTIVE_IPC_NS" ]
    [ "$(readlink /proc/self/ns/net)" != "$DEETTY_ACTIVE_NET_NS" ]
    [ "$DBUS_SESSION_BUS_ADDRESS" != "$DEETTY_ACTIVE_DBUS_FIXTURE" ]
    [ "${LICHFORGE_ISOLATED_DISPLAY:-0}" = 1 ]
    [ "$DEETTY_ISOLATED_WINDOW_MANAGER" != none ]
    [ -z "${DBUS_SYSTEM_BUS_ADDRESS:-}" ]
    [ -z "${SSH_AUTH_SOCK:-}" ]
    [ -z "${XDG_ACTIVATION_TOKEN:-}" ]
    [ ! -S /run/dbus/system_bus_socket ]
    printf "isolated_x11=true\n"
  ')
printf '%s\n' "$x11_output"
printf '%s\n' "$x11_output" | grep -Fx 'isolated_x11=true' >/dev/null

wayland_output=$(DISPLAY=:active-fixture WAYLAND_DISPLAY=wayland-active-fixture \
  DEETTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=30 \
  ./scripts/run_isolated_wayland.sh sh -eu -c '
    ./scripts/require_isolated_display.sh
    [ "$DEETTY_ISOLATED_DISPLAY" = wayland ]
    [ "$XDG_SESSION_TYPE" = wayland ]
    [ -z "${DISPLAY:-}" ]
    [ "$WAYLAND_DISPLAY" = deetty-isolated-wayland ]
    [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]
    printf "isolated_wayland=true\n"
  ')
printf '%s\n' "$wayland_output"
printf '%s\n' "$wayland_output" | grep -Fx 'isolated_wayland=true' >/dev/null

pressure_status=0
DEETTY_DISPLAY_IO_FULL_LIMIT=0 \
  ./scripts/isolated_display_runner.sh -- true >/dev/null 2>&1 ||
  pressure_status=$?
if [ "$pressure_status" -ne 75 ]; then
  echo "isolated_display_smoke error=pressure_gate_status status=$pressure_status" >&2
  exit 1
fi

timeout_status=0
DEETTY_DISPLAY_IO_FULL_LIMIT=101 DEETTY_DISPLAY_BLOCKED_LIMIT=100000 \
  ./scripts/isolated_display_runner.sh --timeout 1 -- sleep 30 \
  >/dev/null 2>&1 || timeout_status=$?
if [ "$timeout_status" -ne 124 ]; then
  echo "isolated_display_smoke error=timeout_status status=$timeout_status" >&2
  exit 1
fi

if DEETTY_ISOLATED_DISPLAY_TIMEOUT_SECONDS=invalid \
  ./scripts/run_isolated_x11.sh true >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=invalid_timeout_accepted' >&2
  exit 1
fi
if DEETTY_ISOLATED_DISPLAY_SCREEN=1280x0x24 \
  ./scripts/run_isolated_x11.sh true >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=invalid_screen_accepted' >&2
  exit 1
fi
if DEETTY_LEGACY_DISPLAY_RUNNER=0 \
  OVERZEER_DISPLAY_RUNNER=/deetty/missing/isolated-runner \
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
DISPLAY=:dedicated-fixture WAYLAND_DISPLAY= DEETTY_DEDICATED_DISPLAY=1 \
  ./scripts/require_isolated_display.sh --dedicated
if DISPLAY=:fixture WAYLAND_DISPLAY= \
  DEETTY_ISOLATED_DISPLAY=unknown \
  ./scripts/require_isolated_display.sh >/dev/null 2>&1; then
  echo 'isolated_display_smoke error=unknown_boundary_accepted' >&2
  exit 1
fi

echo "isolated_display_smoke x11=true wayland=true active_display_inherited=false private_home=true private_xdg=true private_tmp=true mount_namespace=true pid_namespace=true ipc_namespace=true network_namespace=true private_dbus=true private_system_bus=true private_x11_wm=true host_agent_socket=false host_activation_token=false serialized=true pressure_gated=true timeout_bounded=true process_tree_bounded=true dynamic_screen=true shared_runner=$shared_runner legacy_fallback=$legacy_fallback direct_wrappers_fail_closed=true dedicated_ack=true fail_closed=true"
