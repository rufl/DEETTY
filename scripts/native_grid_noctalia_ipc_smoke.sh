#!/usr/bin/env sh
set -eu

if [ "${DINTTY_ISOLATED_DISPLAY:-}" != wayland ] &&
  [ "${DINTTY_DEDICATED_DISPLAY:-0}" != 1 ]; then
  exec ./scripts/run_isolated_wayland.sh "$0" "$@"
fi
./scripts/require_isolated_display.sh

export LC_ALL=C
export NO_AT_BRIDGE=1


ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build
ZIG_GLOBAL_CACHE_DIR=.zig-cache/global zig build smoke-binaries
output=/tmp/dintty-native-grid-noctalia-ipc.txt
ready=/tmp/dintty-noctalia-control-ready
rm -f "$output" "$ready"
GDK_BACKEND=wayland ./zig-out/bin/dintty-smoke --native-grid-noctalia-ipc-smoke >"$output" 2>&1 &
pid=$!
cleanup() {
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$ready"
}
trap cleanup EXIT

attempt=0
while [ "$attempt" -lt 100 ] && [ ! -s "$ready" ]; do
    attempt=$((attempt + 1))
    sleep 0.05
done
if [ ! -s "$ready" ]; then
    cat "$output" >&2
    exit 1
fi

status_hidden="$(timeout 8 ./zig-out/bin/dintty --status)"
show="$(timeout 8 ./zig-out/bin/dintty --show)"
sleep 0.25
hide="$(timeout 8 ./zig-out/bin/dintty --hide)"
toggle="$(timeout 8 ./zig-out/bin/dintty --toggle)"
sleep 0.25
status_visible="$(timeout 8 ./zig-out/bin/dintty --status)"

printf '%s\n' "$status_hidden" | grep -F 'action=status running=true visible=false' >/dev/null
printf '%s\n' "$show" | grep -F 'action=show running=true visible=true' >/dev/null
printf '%s\n' "$hide" | grep -F 'action=hide running=true visible=false' >/dev/null
printf '%s\n' "$toggle" | grep -F 'action=toggle running=true visible=true' >/dev/null
printf '%s\n' "$status_visible" | grep -F 'action=status running=true visible=true' >/dev/null

if wait "$pid"; then
    :
else
    status=$?
    cat "$output" >&2
    exit "$status"
fi
rm -f "$ready"
trap - EXIT
cat "$output"
grep -F 'native_grid_noctalia_ipc_smoke dbus=true layer_shell=false toplevel_fallback=true app_id=com.dintty.DINTTY title_prefix=true hidden_start=true status=true show=true hide=true toggle=true single_instance=true dropdown_dragger=2px side_border=2 exited=true' "$output" >/dev/null
